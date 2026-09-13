import SwiftUI
import AppKit

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if store.folder == nil {
                FolderSetupView()
            } else {
                main
            }
        }
        .alert("読み込みエラー", isPresented: .constant(store.loadError != nil)) {
            Button("再試行") { store.load() }
            Button("閉じる", role: .cancel) { }
        } message: {
            Text(store.loadError ?? "")
        }
    }

    private var main: some View {
        @Bindable var state = state
        return NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            Group {
                if state.period == .completed {
                    CompletedListView()
                } else {
                    KanbanView()
                }
            }
            .navigationTitle("")
            .toolbar { toolbar }
        }
        .sheet(isPresented: $state.showingNew) {
            TaskEditor(task: newTask()) { store.upsert($0) }
        }
        .sheet(item: $state.editing) { task in
            TaskEditor(task: task) { store.upsert($0) }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { state.showingNew = true } label: { Label("新規タスク", systemImage: "plus") }
                .help("新規タスク（⌘N）")
        }
    }

    private func newTask() -> Task {
        let profileID = store.doc.profiles.first { $0.id == settings.defaultProfileID }?.id
            ?? store.doc.profiles.first?.id ?? Profile.fallback.id
        let profile = store.profile(profileID)
        return Task(title: "", status: settings.defaultStatus,
                    priority: settings.defaultPriority, profileID: profileID,
                    due: defaultDueDate(profile), allDay: settings.defaultAllDay)
    }

    private func defaultDueDate(_ profile: Profile) -> Date {
        let base = settings.defaultDue.date()
        let parts = profile.defaultTime.split(separator: ":").compactMap { Int($0) }
        let cal = settings.calendar
        guard parts.count == 2,
              let d = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: base)
        else { return base }
        return d
    }
}

/// 初回起動：保存先フォルダを本人に選んでもらう。
struct FolderSetupView: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 52)).foregroundStyle(.secondary)
            Text("タスクの保存先を選んでください").font(.title3)
            Text("選んだフォルダに tasks.json（正）と tasks.md（読み用）を作ります。\nあとから設定の「詳細」で変更できます。")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(4)
            Button("フォルダを選ぶ…") { pick() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(48)
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "ここに保存"
        if panel.runModal() == .OK, let url = panel.url { store.open(url) }
    }
}
