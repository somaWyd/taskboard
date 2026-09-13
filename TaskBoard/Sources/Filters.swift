import Foundation

enum Period: String, CaseIterable, Identifiable, Codable {
    case today, week, month, all, completed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .today: return "今日"
        case .week: return "今週"
        case .month: return "今月"
        case .completed: return "完了済"
        case .all: return "すべて"
        }
    }
    var symbol: String {
        switch self {
        case .today: return "sun.max"
        case .week: return "calendar.day.timeline.left"
        case .month: return "calendar"
        case .completed: return "checkmark.circle"
        case .all: return "square.stack"
        }
    }

    /// 期限がこの期間に入るか。`completed`/`all` は期限を見ない。
    func contains(_ date: Date, calendar: Calendar) -> Bool {
        switch self {
        case .today: return calendar.isDateInToday(date)
        case .week: return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        case .month: return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        case .completed, .all: return true
        }
    }
}

struct Filter {
    var period: Period = .today
    /// nil = プロファイルで絞らない。集合を渡すとそのぶんだけ（空集合なら0件）
    var profileIDs: Set<String>? = nil
    var calendar: Calendar = .current
    var sort: SortRule = .dateManual
    var profileOrder: [String] = []

    /// 件数だけが要るときは並べ替えを省く。
    /// 数えるのは未完了のみ（「完了済」タブのときだけ完了を数える）。
    func count(_ tasks: [Task]) -> Int {
        tasks.reduce(into: 0) { acc, t in
            guard matches(t) else { return }
            if period == .completed || t.status != .done { acc += 1 }
        }
    }

    private func matches(_ t: Task) -> Bool {
        if t.isSubtask { return false }
        if let profileIDs, !profileIDs.contains(t.profileID) { return false }
        switch period {
        case .completed: return t.status == .done
        case .all: return true
        default: return period.contains(t.due, calendar: calendar)
        }
    }

    /// 親タスクのみを返す（サブタスクは親の下にぶら下げて描くため除外）。
    func apply(_ tasks: [Task], includeSubtasks: Bool = false) -> [Task] {
        let matched = tasks.filter { includeSubtasks ? matchesIgnoringNesting($0) : matches($0) }
        return sort.sort(matched, profileOrder: profileOrder, calendar: calendar)
    }

    private func matchesIgnoringNesting(_ t: Task) -> Bool {
        if let profileIDs, !profileIDs.contains(t.profileID) { return false }
        switch period {
        case .completed: return t.status == .done
        case .all: return true
        default: return period.contains(t.due, calendar: calendar)
        }
    }
}

enum SortRule: String, CaseIterable, Identifiable, Codable {
    case dateManual, priorityTime, timePriority, profilePriority, title
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dateManual: return "日付 → 手動の並び"
        case .priorityTime: return "重要度 → 時間"
        case .timePriority: return "時間 → 重要度"
        case .profilePriority: return "プロファイル → 重要度"
        case .title: return "タイトル順"
        }
    }

    /// 同じ日・同じ時刻のものを1つの束として扱うためのキー。
    /// 時刻なし（終日）はその日の先頭に置く。
    static func groupKey(_ t: Task, _ cal: Calendar) -> (Date, Double) {
        let day = cal.startOfDay(for: t.due)
        guard !t.allDay else { return (day, -1) }
        let c = cal.dateComponents([.hour, .minute], from: t.due)
        return (day, Double((c.hour ?? 0) * 60 + (c.minute ?? 0)))
    }

    func sort(_ tasks: [Task], profileOrder: [String],
              calendar: Calendar = .current) -> [Task] {
        tasks.sorted { a, b in
            switch self {
            case .dateManual:
                let ka = Self.groupKey(a, calendar), kb = Self.groupKey(b, calendar)
                if ka.0 != kb.0 { return ka.0 < kb.0 }
                if ka.1 != kb.1 { return ka.1 < kb.1 }
                return a.manualOrder < b.manualOrder
            case .priorityTime:
                if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
                if a.due != b.due { return a.due < b.due }
                return a.manualOrder < b.manualOrder
            case .timePriority:
                if a.due != b.due { return a.due < b.due }
                if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
                return a.manualOrder < b.manualOrder
            case .profilePriority:
                let ia = profileOrder.firstIndex(of: a.profileID) ?? .max
                let ib = profileOrder.firstIndex(of: b.profileID) ?? .max
                if ia != ib { return ia < ib }
                if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
                return a.manualOrder < b.manualOrder
            case .title:
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
        }
    }
}



extension Array {
    /// 範囲外なら nil。並べ替えの前後どちらかが無いときに使う。
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// サイドバーのプロファイル表示切替。空集合は「全部表示」を表す。
enum ProfileVisibility {
    /// - Parameters:
    ///   - active: いま表示しているプロファイル（空 = 全部）
    ///   - clicked: 押されたプロファイル
    ///   - all: 並び順どおりの全プロファイル
    static func toggle(active: Set<String>, clicked: String, all: [String]) -> Set<String> {
        guard all.contains(clicked) else { return active }
        let everything = Set(all)

        // 全部表示 → 押したものだけにする
        if active.isEmpty { return all.count == 1 ? [] : [clicked] }

        // 押したものだけ表示中 → それを隠して、残り全部を表示する
        if active == [clicked] {
            let rest = everything.subtracting([clicked])
            return rest.isEmpty ? active : rest
        }

        var next = active
        if next.contains(clicked) { next.remove(clicked) } else { next.insert(clicked) }
        if next.isEmpty { return active }               // 全部消えるのは避ける
        return next == everything ? [] : next           // 全部そろったら「全部表示」に畳む
    }
}
