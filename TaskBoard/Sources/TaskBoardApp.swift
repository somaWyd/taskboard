import SwiftUI

@Observable
final class AppState {
    /// 前回見ていた期間を覚えておく。
    var period: Period = Period(rawValue: UserDefaults.standard.string(forKey: "lastPeriod") ?? "") ?? .today {
        didSet { UserDefaults.standard.set(period.rawValue, forKey: "lastPeriod") }
    }
    /// 隠しているプロファイル。ここに無いものは表示する。
    /// 新しく作ったプロファイルは自動で表示されるので、この持ち方にしている。
    var hiddenProfiles: Set<String> = Set(UserDefaults.standard
        .stringArray(forKey: "hiddenProfiles") ?? []) {
        didSet { UserDefaults.standard.set(Array(hiddenProfiles), forKey: "hiddenProfiles") }
    }

    func isVisible(_ id: String) -> Bool { !hiddenProfiles.contains(id) }

    func toggleProfile(_ id: String) {
        if hiddenProfiles.contains(id) { hiddenProfiles.remove(id) }
        else { hiddenProfiles.insert(id) }
    }

    /// 絞り込みに渡す「見えているプロファイル」。全部隠していれば空集合。
    func visibleProfiles(of all: [String]) -> Set<String> {
        Set(all.filter(isVisible))
    }
    var editing: Task?
    var showingNew = false
    /// ⌘N の合図。KanbanView がこれを見てインライン入力を開く。
    var composeRequest = 0
    /// ⌘⌫ の合図。選択中のタスクを削除する。
    var deleteRequest = 0
    var sidebarVisible = true
}

@main
struct TaskBoardApp: App {
    @State private var store = Store()
    @State private var settings = AppSettings()
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(settings)
                .environment(state)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(settings.accent)
                .font(settings.uiFont)
                .frame(minWidth: 820, minHeight: 520)
        }
        .commands { AppCommands(state: state, store: store, settings: settings) }

        Settings {
            SettingsView()
                .environment(store)
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(settings.accent)
        }
    }
}

struct AppCommands: Commands {
    var state: AppState
    var store: Store
    var settings: AppSettings

    var body: some Commands {
        // ファイル
        CommandGroup(replacing: .newItem) {
            Button("新規タスク") { state.composeRequest += 1 }
                .keyboardShortcut("n", modifiers: .command)
            Button("新規タスク（詳細）…") { state.showingNew = true }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Markdownをコピー") { copyMarkdown() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
        }

        // 編集（取り消し・やり直し・削除）
        CommandGroup(replacing: .undoRedo) {
            Button("取り消す") { store.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!store.canUndo)
            Button("やり直す") { store.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!store.canRedo)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("選択したタスクを削除") { state.deleteRequest += 1 }
                .keyboardShortcut(.delete, modifiers: .command)
        }

        // 表示
        CommandGroup(after: .sidebar) {
            Button(state.sidebarVisible ? "サイドバーを隠す" : "サイドバーを表示") {
                state.sidebarVisible.toggle()
            }
            .keyboardShortcut("b", modifiers: .command)
            Divider()
            ForEach(Array(settings.orderedPeriods.enumerated()), id: \.element) { index, period in
                Button(period.label) { state.period = period }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")),
                                      modifiers: .command)
            }
            Divider()
            Button("大きくする") { settings.zoom(by: 1) }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(settings.fontSize >= AppSettings.fontSizeRange.upperBound)
            Button("小さくする") { settings.zoom(by: -1) }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(settings.fontSize <= AppSettings.fontSizeRange.lowerBound)
            Button("標準サイズに戻す") { settings.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
            Divider()
            Button("再読み込み") { store.load() }
                .keyboardShortcut("r", modifiers: .command)
        }
    }

    private func copyMarkdown() {
        let md = Markdown.render(store.doc, options: MDOptions(period: state.period))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
    }
}
