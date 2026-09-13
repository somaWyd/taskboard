import Foundation
import Observation

/// tasks.json を正とするローカルストア。保存のたびに tasks.md も書き出す。
@Observable
final class Store {
    var doc: Document = .starter
    private(set) var folder: URL?
    var loadError: String?

    /// 親ID → サブタスク。毎カードで全件を走査しないための索引。
    private(set) var childIndex: [UUID: [Task]] = [:]

    /// 取り消し用の履歴。保存のたびに直前の内容を積む。
    private var undoStack: [Document] = []
    private var redoStack: [Document] = []
    /// 直前に保存した内容。差分を見て履歴に積むために持つ。
    private var previous: Document?
    /// 取り消し中は履歴を積まない
    private var restoring = false
    private static let historyLimit = 40

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    private var watcher: DispatchSourceFileSystemObject?
    private var saving = false
    private static let folderKey = "storeFolderPath"

    var jsonURL: URL? { folder?.appendingPathComponent("tasks.json") }
    var mdURL: URL? { folder?.appendingPathComponent("tasks.md") }

    init() {
        if let path = UserDefaults.standard.string(forKey: Self.folderKey) {
            open(URL(fileURLWithPath: path))
        }
    }

    // MARK: - フォルダ

    func open(_ url: URL) {
        folder = url
        UserDefaults.standard.set(url.path, forKey: Self.folderKey)
        load()
        writeSchemaDocIfMissing()
        startWatching()
    }

    func forgetFolder() {
        stopWatching()
        folder = nil
        UserDefaults.standard.removeObject(forKey: Self.folderKey)
    }

    // MARK: - 読み書き

    func load() {
        guard let url = jsonURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            doc = .starter
            save()
            return
        }
        do {
            let data = try Data(contentsOf: url)
            doc = try Self.decoder.decode(Document.self, from: data)
            previous = doc                 // 読み込み直後を履歴の起点にする
            rebuildIndex()
            loadError = nil
        } catch {
            // 壊れたファイルを黙って上書きしない。読み込み失敗は必ず見せる。
            loadError = "tasks.json を読めませんでした: \(error.localizedDescription)"
        }
    }

    func save() {
        recordHistory()
        rebuildIndex()
        guard let url = jsonURL, loadError == nil else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            saving = true
            let data = try Self.encoder.encode(doc)
            try data.write(to: url, options: .atomic)
            if let md = mdURL {
                try Markdown.render(doc).data(using: .utf8)?.write(to: md, options: .atomic)
            }
            writeSchemaDocIfMissing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.saving = false }
        } catch {
            saving = false
            loadError = "保存に失敗しました: \(error.localizedDescription)"
        }
    }

    private func rebuildIndex() {
        childIndex = Dictionary(grouping: doc.tasks.filter { $0.isSubtask }) { $0.parentID! }
            .mapValues { $0.sorted { $0.createdAt < $1.createdAt } }
    }

    /// Claude Code など外部のツールが tasks.json を直接編集できるよう、
    /// 同じフォルダに書き方を置いておく（既にあれば触らない）。
    func writeSchemaDocIfMissing() {
        guard let folder else { return }
        let doc = folder.appendingPathComponent("CLAUDE.md")
        guard !FileManager.default.fileExists(atPath: doc.path) else { return }
        try? Self.schemaDoc.data(using: .utf8)?.write(to: doc, options: .atomic)
    }

    private func recordHistory() {
        defer { previous = doc }
        guard !restoring, let previous, previous != doc else { return }
        undoStack.append(previous)
        if undoStack.count > Self.historyLimit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    /// 直前の状態に戻す。
    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(doc)
        restore(last)
    }

    /// 取り消した操作をやり直す。
    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(doc)
        restore(next)
    }

    private func restore(_ snapshot: Document) {
        restoring = true
        doc = snapshot
        previous = snapshot
        save()
        restoring = false
    }

    // MARK: - 外部編集の取り込み

    private func startWatching() {
        stopWatching()
        guard let url = jsonURL, FileManager.default.fileExists(atPath: url.path) else { return }
        let fd = Foundation.open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self, !self.saving else { return }
            self.load()
            self.startWatching()   // atomic 置換でfdが外れるので張り直す
        }
        src.setCancelHandler { Foundation.close(fd) }
        src.resume()
        watcher = src
    }

    private func stopWatching() {
        watcher?.cancel()
        watcher = nil
    }

    // MARK: - 変更

    func upsert(_ task: Task) {
        if let i = doc.tasks.firstIndex(where: { $0.id == task.id }) {
            doc.tasks[i] = task
        } else {
            doc.tasks.append(task)
        }
        save()
    }

    func delete(_ task: Task) {
        doc.tasks.removeAll { $0.id == task.id || $0.parentID == task.id }
        save()
    }

    /// ステータス変更。Done にしたとき、繰り返しタスクなら次回を生成する。
    func move(_ task: Task, to status: Status) {
        guard var t = doc.tasks.first(where: { $0.id == task.id }), t.status != status else { return }
        t.status = status
        t.completedAt = (status == .done) ? Date() : nil
        if status == .done,
           let nextDue = t.repeatRule.next(after: t.due, weekdays: t.repeatWeekdays) {
            var follow = t
            follow.id = UUID()
            follow.status = .inbox
            follow.due = nextDue
            follow.completedAt = nil
            follow.createdAt = Date()
            doc.tasks.append(follow)
        }
        upsert(t)
    }

    func profile(_ id: String) -> Profile {
        doc.profiles.first { $0.id == id } ?? .fallback
    }

    static let schemaDoc = """
    # TaskBoard のデータ

    - **正データは `tasks.json`。** これを編集すればアプリに反映される（起動中でも自動で読み直す）。
    - `tasks.md` はアプリが毎回上書きする**読み取り専用の写し**。ここを編集しても取り込まれない。

    ## tasks.json の形

    ```json
    {
      "version": 1,
      "profiles": [
        { "id": "work", "name": "仕事", "symbol": "briefcase.fill",
          "colorHex": "#0A84FF", "defaultTime": "10:00" }
      ],
      "tasks": [
        { "id": "8E2F...(UUID)", "title": "資料を共有",
          "status": "inbox", "priority": 2, "profile": "work",
          "due": "2026-09-14T17:00:00+09:00", "memo": "",
          "repeat": "none",
          "createdAt": "2026-09-13T09:00:00+09:00",
          "completedAt": null, "parentID": null }
      ]
    }
    ```

    | フィールド | 値 |
    |---|---|
    | `status` | `inbox` / `next` / `done` |
    | `priority` | `1`=低 / `2`=中 / `3`=高 |
    | `profile` | `profiles[].id` のどれか |
    | `due` | ISO8601。必須（未設定にはできない） |
    | `repeat` | `none` / `daily` / `weekdays` / `weekly` / `monthly` |
    | `completedAt` | `status` が `done` のときだけ日時。それ以外は `null` |
    | `parentID` | サブタスクなら親タスクの `id`。通常タスクは `null` |

    ## 編集するときの決まり

    1. `id` は UUID 文字列。新規タスクは必ず新しい UUID を振る
    2. `parentID` は1段まで。サブタスクのサブタスクは作らない
    3. サブタスクの `status` は親と揃える
    4. 親を消すときは、その `parentID` を持つタスクも一緒に消す
    5. 書き込みは一時ファイル→`rename` の原子的置換で行う（書きかけを読ませない）
    6. アプリを開いたまま編集した場合、**最後に書いた側が勝つ**
    """

    // MARK: - JSON設定

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

// MARK: - サブタスクと一括操作

extension Store {
    func subtasks(of parent: Task) -> [Task] {
        childIndex[parent.id] ?? []
    }

    /// インライン追加。template の属性（期限・プロファイル等）を引き継ぐ。
    @discardableResult
    func add(title: String, like template: Task, parent: Task? = nil) -> Task? {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        var t = template
        t.id = UUID()
        t.title = name
        t.createdAt = Date()
        t.completedAt = nil
        t.parentID = parent?.id
        if let parent { t.status = parent.status; t.due = parent.due }
        doc.tasks.append(t)
        save()
        return t
    }

    func toggleDone(_ task: Task) {
        move(task, to: task.status == .done ? .inbox : .done)
    }

    func bulkMove(_ ids: Set<UUID>, to status: Status) {
        for id in ids {
            guard let t = doc.tasks.first(where: { $0.id == id }) else { continue }
            move(t, to: status)
        }
    }

    func bulkDelete(_ ids: Set<UUID>) {
        // 親を消したらサブタスクも道連れにする（孤児を作らない）
        doc.tasks.removeAll { ids.contains($0.id) || ($0.parentID.map(ids.contains) ?? false) }
        save()
    }

    /// task を parent のサブタスクにする。階層は2段までに保つ。
    func makeSubtask(_ task: Task, of parent: Task) -> Bool {
        guard task.id != parent.id, !parent.isSubtask,
              var t = doc.tasks.first(where: { $0.id == task.id }) else { return false }
        // 自分の子は、孫にせず新しい親の直下へ移す（階層を増やさない）
        for var child in subtasks(of: task) {
            child.parentID = parent.id
            child.status = parent.status
            upsert(child)
        }
        t.parentID = parent.id
        t.status = parent.status
        upsert(t)
        return true
    }

    /// 子を親から切り離して独立したタスクにする。
    func detach(_ task: Task) {
        guard var t = doc.tasks.first(where: { $0.id == task.id }), t.isSubtask else { return }
        t.parentID = nil
        upsert(t)
    }

    /// 親を動かしたらサブタスクも同じ列へ連れて行く。
    func moveWithSubtasks(_ task: Task, to status: Status) {
        move(task, to: status)
        for sub in subtasks(of: task) { move(sub, to: status) }
    }
}
