import SwiftUI

/// 「完了済」はカンバンではなくリストで見る。日付ごとにまとめる。
struct CompletedListView: View {
    @Environment(Store.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(AppState.self) private var state
    @State private var selection: Set<UUID> = []

    var body: some View {
        List(selection: $selection) {
            ForEach(groups, id: \.0) { day, items in
                Section(day) {
                    ForEach(items) { task in
                        row(task).tag(task.id)
                    }
                }
            }
            if groups.isEmpty {
                ContentUnavailableView("完了したタスクはありません",
                                       systemImage: "checkmark.circle",
                                       description: Text("カンバンでDoneに入れたタスクがここに並びます"))
            }
        }
        .listStyle(.inset)
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button("Inbox に戻す") { store.bulkMove(ids, to: .inbox) }
            Button("\(ids.count)件を削除", role: .destructive) { store.bulkDelete(ids) }
        }
    }

    private func row(_ task: Task) -> some View {
        let profile = store.profile(task.profileID)
        return HStack(spacing: 10) {
            Button { store.toggleDone(task) } label: {
                Image(systemName: "largecircle.fill.circle").foregroundStyle(.tint)
            }
            .buttonStyle(.plain)

            Circle().fill(settings.color(for: task.priority)).frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).strikethrough().foregroundStyle(.secondary)
                if !task.memo.isEmpty {
                    Text(task.memo).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer()
            Label(profile.name, systemImage: profile.symbol)
                .font(.caption2)
                .foregroundStyle(Color(hex: profile.colorHex))
            Text(stamp(task.completedAt ?? task.due))
                .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
        }
        .padding(.vertical, 3)
        .onTapGesture(count: 2) { state.editing = task }
    }

    private var groups: [(String, [Task])] {
        let filter = Filter(period: .completed, profileIDs: state.activeProfiles,
                            calendar: settings.calendar, sort: settings.sortRule,
                            profileOrder: store.doc.profiles.map(\.id))
        let done = filter.apply(store.doc.tasks, includeSubtasks: true)
            .sorted { ($0.completedAt ?? $0.due) > ($1.completedAt ?? $1.due) }
        let keyed = Dictionary(grouping: done) { day($0.completedAt ?? $0.due) }
        return keyed.sorted { $0.key > $1.key }.map { ($0.key, $0.value) }
    }

    private func day(_ d: Date) -> String { fmt("yyyy年M月d日(E)").string(from: d) }
    private func stamp(_ d: Date) -> String { fmt("HH:mm").string(from: d) }

    private func fmt(_ p: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = p
        return f
    }
}
