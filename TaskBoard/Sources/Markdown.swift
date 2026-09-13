import Foundation

enum MDGroup: String, CaseIterable, Identifiable, Codable {
    case status, date, profile
    var id: String { rawValue }
    var label: String {
        switch self {
        case .status: return "ステータス"
        case .date: return "日付"
        case .profile: return "プロファイル"
        }
    }
}

struct MDOptions: Codable {
    var period: Period = .week
    var group: MDGroup = .status
    var includeDue = true
    var includePriority = true
    var includeProfile = true
    var includeMemo = false
    var includeDone = false
}

enum Markdown {
    static func render(_ doc: Document, options: MDOptions = MDOptions()) -> String {
        var filter = Filter()
        filter.period = options.period
        var tasks = filter.apply(doc.tasks)
        if !options.includeDone { tasks.removeAll { $0.status == .done } }

        let profiles = Dictionary(uniqueKeysWithValues: doc.profiles.map { ($0.id, $0) })
        var out = ["# タスク（\(options.period.label)）", ""]
        for (heading, group) in grouped(tasks, by: options.group, profiles: profiles) {
            out.append("## \(heading)")
            for t in group { out.append(line(t, options, profiles)) }
            out.append("")
        }
        if tasks.isEmpty { out.append("_該当するタスクはありません_") }
        return out.joined(separator: "\n")
    }

    private static func grouped(_ tasks: [Task], by group: MDGroup,
                                profiles: [String: Profile]) -> [(String, [Task])] {
        switch group {
        case .status:
            return Status.allCases.compactMap { s in
                let g = tasks.filter { $0.status == s }
                return g.isEmpty ? nil : (s.label, g)
            }
        case .profile:
            let keys = Array(Set(tasks.map(\.profileID))).sorted()
            return keys.compactMap { k in
                let g = tasks.filter { $0.profileID == k }
                return g.isEmpty ? nil : (profiles[k]?.name ?? k, g)
            }
        case .date:
            let keys = Array(Set(tasks.map { dayKey($0.due) })).sorted()
            return keys.map { k in (k, tasks.filter { dayKey($0.due) == k }) }
        }
    }

    private static func line(_ t: Task, _ o: MDOptions, _ profiles: [String: Profile]) -> String {
        var parts = ["- [\(t.status == .done ? "x" : " ")] \(t.title)"]
        if o.includePriority { parts.append("(重要度: \(t.priority.label))") }
        if o.includeDue {
            parts.append("(\(t.allDay ? fmt("MM/dd").string(from: t.due) : stamp(t.due)))")
        }
        if o.includeProfile { parts.append("#\(profiles[t.profileID]?.name ?? t.profileID)") }
        var out = parts.joined(separator: " ")
        if o.includeMemo, !t.memo.isEmpty {
            let memo = t.memo.split(separator: "\n").map { "  > \($0)" }.joined(separator: "\n")
            out += "\n" + memo
        }
        return out
    }

    private static func dayKey(_ d: Date) -> String { fmt("yyyy-MM-dd").string(from: d) }
    private static func stamp(_ d: Date) -> String { fmt("MM/dd HH:mm").string(from: d) }

    private static func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = pattern
        return f
    }
}
