import SwiftUI

private struct CardFrames: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// ドラッグ中のカーソル位置だけを持つ。盤面本体がこれを読まないので、
/// 指を動かしただけでカンバン全体が描き直されることがなくなる。
@Observable
final class DragPointModel {
    var point: CGPoint = .zero
}

/// カーソルに追従するゴースト。座標を読むのはこのビューだけ。
struct GhostLayer: View {
    let model: DragPointModel
    let task: Task
    let width: CGFloat
    let offset: CGSize

    var body: some View {
        CardView(task: task, ghost: true)
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true)
            .position(x: model.point.x + offset.width, y: model.point.y + offset.height)
            .allowsHitTesting(false)
    }
}

struct KanbanView: View {
    @Environment(Store.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(AppState.self) private var state

    @State private var boardSize: CGSize = .zero
    @State private var dragging: Task?
    @State private var dragModel = DragPointModel()
    @State private var grabOffset: CGSize = .zero
    @State private var hover: Status?
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var session: BoardDrag?
    @State private var drop: BoardDrag.Drop?
    @State private var selection: Set<UUID> = []
    @State private var composing: Status?
    @State private var draft = ""
    @State private var draftTask = Task(title: "", profileID: "", due: Date())
    @State private var showDraftMemo = false
    @State private var hoverEmpty: Status?
    @State private var subtaskParent: UUID?
    @State private var subtaskDraft = ""
    @FocusState private var focus: String?

    private let columns: [Status] = [.inbox, .next, .done]

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 12) {
                let layouts = columnLayouts()
                ForEach(visibleColumns, id: \.self) { status in
                    if let layout = layouts[status] { column(layout) }
                }
            }
            .padding(14)

            if let dragging {
                GhostLayer(model: dragModel, task: dragging,
                           width: session?.cardWidth ?? 260, offset: grabOffset)
                    .transition(.opacity)
            }
        }
        .coordinateSpace(name: "board")
        .onExitCommand {
            if !selection.isEmpty { withAnimation(Motion.quick) { selection = [] } }
            else if composing != nil { cancelComposing() }
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { boardSize = geo.size }
                    .onChange(of: geo.size) { _, size in boardSize = size }
            }
        }
        .onPreferenceChange(CardFrames.self) { cardFrames = $0 }
        .onChange(of: state.period) { _, _ in selection = []; composing = nil }
    }

    /// 列の矩形。HStack の余白14pt・間隔12pt・等幅という配置から計算する。
    /// 実測値を別に集めると、片方だけ古くなったときに気づけない。
    private func columnRects() -> [Status: CGRect] {
        let cols = visibleColumns
        guard !cols.isEmpty, boardSize.width > 0 else { return [:] }
        let pad: CGFloat = 14, gap: CGFloat = 12
        let width = (boardSize.width - pad * 2 - gap * CGFloat(cols.count - 1))
            / CGFloat(cols.count)
        guard width > 0 else { return [:] }
        var rects: [Status: CGRect] = [:]
        for (i, status) in cols.enumerated() {
            rects[status] = CGRect(x: pad + (width + gap) * CGFloat(i), y: pad,
                                   width: width, height: max(boardSize.height - pad * 2, 0))
        }
        return rects
    }

    private var visibleColumns: [Status] {
        settings.showDoneColumn ? columns : [.inbox, .next]
    }

    // MARK: - 列

    private func column(_ layout: ColumnLayout) -> some View {
        let status = layout.status
        return VStack(alignment: .leading, spacing: 0) {
            header(status, count: layout.parents.count)
            GeometryReader { geo in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(layout.rows) { row in
                            if row.showsInsertionLine,
                               drop == .insert(status, row.insertBefore) { insertionLine }
                            rowView(row)
                            if subtaskParent == row.groupParentID, row.isGroupEnd,
                               let parent = layout.parents.first(where: { $0.id == row.groupParentID }) {
                                subtaskComposer(parent)
                                    .padding(.leading, subtaskIndent)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity))
                            }
                        }
                        if drop == .insert(status, layout.endIndex) { insertionLine }
                        if composing == status {
                            composer(status)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity))
                        }
                        addTarget(status, empty: layout.isEmpty && composing != status)
                    }
                    .frame(minHeight: geo.size.height, alignment: .top)
                    .background { addBackground(status) }
                    .animation(Motion.settle, value: layout.rows.map(\.id))
                    .animation(Motion.settle, value: composing)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .panel(settings.surface, radius: 12)
        .hairline(12, color: hover == status ? .accentColor : .clear,
                  width: hover == status ? 2 : 0)
        .animation(Motion.quick, value: hover)
    }

    private func header(_ status: Status, count: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: status.symbol)
            Text(status.label).fontWeight(.medium)
            Text("\(count)")
                .monospacedDigit()
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
            Spacer()
        }
        .font(.body)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 5)
        .padding(.bottom, 12)
    }

    // MARK: - カード

    /// 親も子も必ずここを通る。描かれた行は必ず座標を報告するので、
    /// 判定表に載らない行が生まれない。
    private func rowView(_ row: ColumnLayout.Row) -> some View {
        let task = row.task
        let isDragging = dragging?.id == task.id
        return CardView(task: task,
                        selected: selection.contains(task.id),
                        isSubtask: row.isSubtask,
                        onToggle: row.isSubtask ? { withAnimation(Motion.settle) { store.toggleDone(task) } } : nil,
                        onAddSubtask: row.isSubtask ? nil : { beginSubtask(task) })
            .opacity(isDragging ? 0 : 1)
            .animation(nil, value: isDragging)
            .overlay { if isDragging { emptySlot } }
            .hairline(10, color: drop == .subtask(task.id) ? .accentColor : .clear,
                      width: drop == .subtask(task.id) ? 2.5 : 0)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: CardFrames.self,
                                           value: [task.id: geo.frame(in: .named("board"))])
                }
            }
            .padding(.leading, row.isSubtask ? subtaskIndent : 0)
            .overlay(alignment: .leading) {
                if row.isSubtask {
                    Capsule().fill(Color.primary.opacity(0.16))
                        .frame(width: 1.5)
                        .padding(.vertical, 2).padding(.leading, 11)
                }
            }
            .transition(.opacity)
            .animation(Motion.quick, value: drop)
            .gesture(drag(task))
            .onTapGesture { tap(task) }
            .contextMenu { menu(task) }
    }

    /// 子カードの左インデント。この差がそのまま親との幅の差になる。
    private var subtaskIndent: CGFloat { 30 }

    private var insertionLine: some View {
        Capsule().fill(.tint).frame(height: 2.5).padding(.horizontal, 2)
            .transition(.opacity)
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: 9)
            .strokeBorder(.tint.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            .background(RoundedRectangle(cornerRadius: 9).fill(.tint.opacity(0.06)))
    }

    @ViewBuilder
    private func menu(_ task: Task) -> some View {
        let targets = selection.contains(task.id) && selection.count > 1
            ? selection : [task.id]
        ForEach(Status.allCases.filter { $0 != task.status }) { s in
            Button("\(s.label) へ移動") { store.bulkMove(Set(targets), to: s) ; selection = [] }
        }
        Divider()
        Button("サブタスクを追加") { beginSubtask(task) }
        Button("編集…") { state.editing = task }
        Divider()
        Button(targets.count > 1 ? "\(targets.count)件を削除" : "削除", role: .destructive) {
            store.bulkDelete(Set(targets)); selection = []
        }
    }

    private func tap(_ task: Task) {
        let mods = NSEvent.modifierFlags
        if mods.contains(.command) {
            selection.formSymmetricDifference([task.id])
        } else if mods.contains(.shift) {
            selection.insert(task.id)
        } else {
            selection = selection == [task.id] ? [] : [task.id]
        }
    }

    // MARK: - ドラッグ

    private func drag(_ task: Task) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named("board"))
            .onChanged { value in
                // begin の直後は @State の反映を待たず、作った値をそのまま使う
                let current = session ?? begin(task, at: value.startLocation)
                dragModel.point = value.location
                let next = current.drop(at: value.location)
                if next != drop { drop = next }
                hover = hoverColumn(for: next)
            }
            .onEnded { value in
                defer { endDrag() }
                DragLog.end(session, at: value.location)
                guard let session, let result = session.drop(at: value.location) else { return }
                let moving = draggedGroup(task)
                withAnimation(Motion.settle) { apply(result, moving: moving) }
            }
    }

    private func hoverColumn(for result: BoardDrag.Drop?) -> Status? {
        switch result {
        case .insert(let status, _): return status
        default: return nil
        }
    }

    /// 開始時に盤面を写し取る。以後はこのスナップショットだけで判定する。
    /// 並びは描画と同じ ColumnLayout から作るので、両者がずれない。
    @discardableResult
    private func begin(_ task: Task, at start: CGPoint) -> BoardDrag {
        let own = Set(store.subtasks(of: task).map(\.id) + [task.id])
        let layouts = columnLayouts()
        var order: [Status: [BoardDrag.Row]] = [:]
        var parentCount: [Status: Int] = [:]
        var missing = 0

        for status in visibleColumns {
            guard let layout = layouts[status] else { continue }
            parentCount[status] = layout.parents.count
            var rows: [BoardDrag.Row] = []
            for row in layout.rows where !own.contains(row.task.id) {
                guard let frame = cardFrames[row.task.id] else { missing += 1; continue }
                rows.append(.init(id: row.task.id, frame: frame,
                                  canBeParent: !row.isSubtask,
                                  insertBefore: row.insertBefore))
            }
            order[status] = rows
        }

        let frame = cardFrames[task.id]
        let center = CGPoint(x: frame?.midX ?? start.x, y: frame?.midY ?? start.y)
        let rects = columnRects()
        let fallbackWidth = max((rects[task.status]?.width ?? 280) - 20, 160)

        let made = BoardDrag(task: task,
                             // 横方向はカーソル中央に固定する。掴んだ位置のずれを
                             // 残すと、カードの端を掴んだときにゴーストが隣の列まで
                             // はみ出し、「見えている場所」と「判定する場所」が食い違う。
                             grabOffset: CGSize(width: 0,
                                                height: center.y - start.y),
                             cardWidth: frame?.width ?? fallbackWidth,
                             columns: rects,
                             order: order,
                             parentCount: parentCount)
        session = made
        grabOffset = made.grabOffset
        withAnimation(Motion.lift) { dragging = task }
        DragLog.begin(made, missingFrames: missing, start: start)
        return made
    }

    private func apply(_ result: BoardDrag.Drop, moving: [Task]) {
        switch result {
        case .subtask(let parentID):
            guard let parent = store.doc.tasks.first(where: { $0.id == parentID }) else { return }
            for t in moving where t.id != parent.id { _ = store.makeSubtask(t, of: parent) }
        case .insert(let status, let index):
            for t in moving {
                // 列の余白へ落とした子は、親から外れて通常タスクに戻る
                if t.isSubtask { store.detach(t) }
                if t.status != status { store.moveWithSubtasks(t, to: status) }
            }
            reorder(moving, in: status, to: index)
        }
    }

    /// 掴んだカードが選択に含まれていれば、選択ぜんぶをまとめて運ぶ。
    private func draggedGroup(_ task: Task) -> [Task] {
        guard selection.count > 1, selection.contains(task.id) else { return [task] }
        return store.doc.tasks.filter { selection.contains($0.id) }
    }

    private func endDrag() {
        withAnimation(Motion.settle) {
            dragging = nil; hover = nil; drop = nil; session = nil
        }
    }

    /// 落とした位置に居座らせる。上の隣と同じ日時に揃えたうえで、手動の並び順を挟み込む。
    private func reorder(_ moving: [Task], in status: Status, to index: Int) {
        let parents = columnLayouts()[status]?.parents ?? []
        let others = parents.filter { t in !moving.contains { $0.id == t.id } }
        let above = index > 0 ? others[safe: index - 1] : nil
        let below = others[safe: index]
        let lower = above?.manualOrder ?? ((below?.manualOrder ?? 0) - 2)
        let upper = below?.manualOrder ?? ((above?.manualOrder ?? 0) + 2)
        let anchor = above ?? below

        for (offset, t) in moving.enumerated() {
            guard var fresh = store.doc.tasks.first(where: { $0.id == t.id }) else { continue }
            if let anchor {
                fresh.due = anchor.due
                fresh.allDay = anchor.allDay
            }
            let step = (upper - lower) / Double(moving.count + 1)
            fresh.manualOrder = lower + step * Double(offset + 1)
            store.upsert(fresh)
        }
    }

    // MARK: - インライン追加（リマインダー式）

    /// 余白そのものをクリック領域にする。空の列では下まで伸ばす。
    /// カードの背面に敷く当たり判定。カード同士の隙間を押しても追加できる。
    private func addBackground(_ status: Status) -> some View {
        Button { emptyAreaTapped(status) } label: {
            Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 余白クリック：選択中ならまず選択を外す。何も選んでいなければ追加に入る。
    private func emptyAreaTapped(_ status: Status) {
        if !selection.isEmpty {
            withAnimation(Motion.quick) { selection = [] }
            return
        }
        startComposing(status)
    }

    /// 列の余白すべてを追加用の当たり判定にする。カードの隙間から下端まで反応する。
    private func addTarget(_ status: Status, empty: Bool) -> some View {
        Button { emptyAreaTapped(status) } label: {
            ZStack(alignment: .top) {
                Color.clear
                if empty {
                    VStack(spacing: 8) {
                        Image(systemName: status == .done ? "folder" : "plus.circle")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.primary.opacity(0.10))
                        Text(status == .done ? "完了したタスクをここへ" : "クリックして追加")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .frame(maxHeight: .infinity)
                } else if hoverEmpty == status {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("クリックして追加").font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { over in
            guard dragging == nil else { return }
            withAnimation(Motion.quick) { hoverEmpty = over ? status : nil }
        }
    }

    /// タイトルだけでなく、期限・重要度・プロファイル・メモをその場で決められる入力欄。
    private func composer(_ status: Status) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Circle().strokeBorder(.tertiary, lineWidth: 1.4).frame(width: 15, height: 15)
                TextField("新しいタスク", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: settings.fontSize + 1))
                    .focused($focus, equals: "column-\(status.rawValue)")
                    .onSubmit { commitDraft(status) }
            }
            attributeRow
            if showDraftMemo {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text").font(.caption).foregroundStyle(.tertiary)
                    TextField("", text: $draftTask.memo, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .lineLimit(1...3)
                }
                .padding(.leading, 21)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 13)
        .panel(settings.surface, radius: 10, elevated: true)
        .hairline(10, color: .accentColor, width: 1.5)
        .onExitCommand { cancelComposing() }
    }

    private var attributeRow: some View {
        HStack(spacing: 8) {
            ForEach(Priority.allCases) { p in
                Button { draftTask.priority = p } label: {
                    Circle()
                        .fill(settings.color(for: p))
                        .frame(width: 11, height: 11)
                        .overlay {
                            Circle().strokeBorder(.primary,
                                                  lineWidth: draftTask.priority == p ? 1.5 : 0)
                        }
                        .opacity(draftTask.priority == p ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .help("重要度 \(p.label)")
            }

            Divider().frame(height: 14)

            Menu {
                ForEach(DefaultDue.allCases) { d in
                    Button(d.label) { setDraftDay(d.date()) }
                }
            } label: {
                Text(dueLabel).font(.caption).monospacedDigit()
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .tint(Color.secondary)

            if draftTask.allDay {
                Button("その日中") { setTimed() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("クリックすると時刻を決められます")
            } else {
                DatePicker("", selection: $draftTask.due, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .font(.caption)
            }
            Button { if draftTask.allDay { setTimed() } else { draftTask.allDay = true } } label: {
                Image(systemName: draftTask.allDay ? "clock.badge.xmark" : "clock")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(draftTask.allDay ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .help(draftTask.allDay ? "時刻を決める" : "時間を指定しない（その日中）")

            Menu {
                ForEach(store.doc.profiles) { p in
                    Button { draftTask.profileID = p.id } label: {
                        Label(p.name, systemImage: p.symbol)
                    }
                }
            } label: {
                Image(systemName: store.profile(draftTask.profileID).symbol)
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .tint(Color(hex: store.profile(draftTask.profileID).colorHex))
            .help(store.profile(draftTask.profileID).name)

            Menu {
                ForEach(Repeat.allCases) { r in
                    if r == .customWeekly {
                        Menu(r.label) {
                            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { i, name in
                                Button {
                                    draftTask.repeatRule = .customWeekly
                                    if let k = draftTask.repeatWeekdays.firstIndex(of: i + 1) {
                                        draftTask.repeatWeekdays.remove(at: k)
                                    } else {
                                        draftTask.repeatWeekdays.append(i + 1)
                                    }
                                    if draftTask.repeatWeekdays.isEmpty {
                                        draftTask.repeatRule = .none
                                    }
                                } label: {
                                    Label(name, systemImage: draftTask.repeatWeekdays.contains(i + 1)
                                          ? "checkmark.circle.fill" : "circle")
                                }
                            }
                        }
                    } else {
                        Button {
                            draftTask.repeatRule = r
                            if r != .customWeekly { draftTask.repeatWeekdays = [] }
                        } label: {
                            Label(r.label, systemImage: draftTask.repeatRule == r
                                  ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "repeat").font(.caption)
                    if draftTask.repeatRule == .customWeekly, !draftTask.repeatWeekdays.isEmpty {
                        Text(draftTask.repeatWeekdays.sorted()
                            .map { weekdaySymbols[$0 - 1] }.joined()).font(.caption)
                    }
                }
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .tint(draftTask.repeatRule == .none ? Color.secondary : Color.accentColor)
            .help("繰り返し")

            Spacer(minLength: 0)

            Button { showDraftMemo.toggle() } label: {
                Image(systemName: showDraftMemo ? "note.text" : "note")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(showDraftMemo ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .help("メモ")

            Button { commitDraft(draftTask.status) } label: {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty
                             ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            .help("登録（Return）")
        }
        .padding(.leading, 21)
        .foregroundStyle(.secondary)
    }

    private var dueLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: draftTask.due)
    }

    /// 終日から時間ありへ。時刻はプロファイルの既定値を使う。
    private func setTimed() {
        draftTask.allDay = false
        let profile = store.profile(draftTask.profileID)
        let parts = profile.defaultTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              let d = settings.calendar.date(bySettingHour: parts[0], minute: parts[1],
                                             second: 0, of: draftTask.due) else { return }
        draftTask.due = d
    }

    private func setDraftDay(_ day: Date) {
        let cal = settings.calendar
        let time = cal.dateComponents([.hour, .minute], from: draftTask.due)
        draftTask.due = cal.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0,
                                 second: 0, of: day) ?? day
    }

    private func startComposing(_ status: Status) {
        guard composing != status else { return }
        draftTask = blankTask()
        draftTask.status = status
        showDraftMemo = false
        withAnimation(Motion.settle) { composing = status }
        draft = ""
        focus = "column-\(status.rawValue)"
    }

    private func cancelComposing() {
        withAnimation(Motion.settle) { composing = nil }
        draft = ""
        showDraftMemo = false
    }

    /// Enter で確定し、リマインダー同様に次の入力欄を開いたままにする。
    private func commitDraft(_ status: Status) {
        var template = draftTask
        template.status = status
        guard withAnimation(Motion.settle, { store.add(title: draft, like: template) }) != nil else {
            cancelComposing(); return
        }
        // リマインダー同様、確定したらそのまま次の1件を待つ。属性は引き継ぐ
        draft = ""
        draftTask.memo = ""
        focus = "column-\(status.rawValue)"
    }

    private func beginSubtask(_ parent: Task) {
        withAnimation(Motion.settle) { subtaskParent = parent.id }
        subtaskDraft = ""
        focus = "sub-\(parent.id)"
    }

    private func subtaskComposer(_ parent: Task) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Circle()
                .strokeBorder(.tertiary, lineWidth: 1.3)
                .frame(width: 13, height: 13)
            TextField("サブタスク", text: $subtaskDraft)
                .textFieldStyle(.plain)
                .font(.system(size: settings.fontSize))
                .focused($focus, equals: "sub-\(parent.id)")
                .onSubmit { commitSubtask(parent) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13).padding(.vertical, 13)
        .panel(settings.surface, radius: 10, elevated: true)
        .hairline(10, color: .accentColor, width: 1.5)
        .onExitCommand { cancelSubtask() }
        .onChange(of: focus) { _, now in
            if now != "sub-\(parent.id)", subtaskDraft.isEmpty { cancelSubtask() }
        }
    }

    private func commitSubtask(_ parent: Task) {
        guard withAnimation(Motion.settle, {
            store.add(title: subtaskDraft, like: parent, parent: parent)
        }) != nil else { cancelSubtask(); return }
        subtaskDraft = ""
        focus = "sub-\(parent.id)"
    }

    private func cancelSubtask() {
        withAnimation(Motion.settle) { subtaskParent = nil }
        subtaskDraft = ""
    }

    private func blankTask() -> Task {
        let profileID = store.doc.profiles.first { $0.id == settings.defaultProfileID }?.id
            ?? store.doc.profiles.first?.id ?? Profile.fallback.id
        let profile = store.profile(profileID)
        let parts = profile.defaultTime.split(separator: ":").compactMap { Int($0) }
        let base = settings.defaultDue.date()
        let due = parts.count == 2
            ? (settings.calendar.date(bySettingHour: parts[0], minute: parts[1],
                                      second: 0, of: base) ?? base)
            : base
        return Task(title: "", status: .inbox, priority: settings.defaultPriority,
                    profileID: profileID, due: due, allDay: settings.defaultAllDay)
    }

    // MARK: - データ

    /// 盤面ぶんの絞り込みと並べ替えを1回で済ませ、列ごとの並びを組み立てる。
    /// 描画・ドロップ判定・並べ替えは、すべてこの結果だけを見る。
    private func columnLayouts() -> [Status: ColumnLayout] {
        let filter = Filter(period: state.period,
                            profileIDs: state.visibleProfiles(of: store.doc.profiles.map(\.id)),
                            calendar: settings.calendar, sort: settings.sortRule,
                            profileOrder: store.doc.profiles.map(\.id))
        var grouped: [Status: [Task]] = [:]
        for task in filter.apply(store.doc.tasks) {
            grouped[task.status, default: []].append(task)
        }
        if state.period != .completed, settings.doneRetentionDays >= 0 {
            grouped[.done] = trimmedDone(grouped[.done] ?? [])
        }
        var layouts: [Status: ColumnLayout] = [:]
        for status in visibleColumns {
            layouts[status] = ColumnLayout(status: status,
                                           parents: grouped[status] ?? [],
                                           children: { store.subtasks(of: $0) })
        }
        return layouts
    }

    /// Done列に残す範囲。0日なら完了した時点で隠す。
    private func trimmedDone(_ items: [Task]) -> [Task] {
        guard settings.doneRetentionDays > 0 else { return [] }
        let limit = settings.calendar.date(byAdding: .day,
                                           value: -settings.doneRetentionDays, to: Date())
        return items.filter { ($0.completedAt ?? $0.due) >= (limit ?? .distantPast) }
    }
}
