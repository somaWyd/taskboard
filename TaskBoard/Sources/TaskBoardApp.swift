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
        .commands { AppCommands(state: state, store: store) }

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

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("新規タスク") { state.showingNew = true }
                .keyboardShortcut("n", modifiers: .command)
            Divider()
            Button("Markdownをコピー") {
                let md = Markdown.render(store.doc, options: MDOptions(period: state.period))
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(md, forType: .string)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
        CommandGroup(after: .toolbar) {
            Button("再読み込み") { store.load() }
                .keyboardShortcut("r", modifiers: .command)
        }
    }
}
