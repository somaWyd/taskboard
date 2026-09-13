import Foundation

enum Status: String, Codable, CaseIterable, Identifiable {
    case inbox, next, done
    var id: String { rawValue }
    var label: String {
        switch self {
        case .inbox: return "Inbox"
        case .next: return "Next Action"
        case .done: return "Done"
        }
    }
    var symbol: String {
        switch self {
        case .inbox: return "tray"
        case .next: return "play.circle"
        case .done: return "checkmark"
        }
    }
}

enum Priority: Int, Codable, CaseIterable, Identifiable {
    case low = 1, mid = 2, high = 3
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .low: return "低"
        case .mid: return "中"
        case .high: return "高"
        }
    }
}

enum Repeat: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekdays, weekly, monthly, yearly, customWeekly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "なし"
        case .daily: return "毎日"
        case .weekdays: return "平日"
        case .weekly: return "毎週（同じ曜日）"
        case .monthly: return "毎月（同じ日付）"
        case .yearly: return "毎年（同じ月日）"
        case .customWeekly: return "曜日を指定"
        }
    }

    /// 次回の期限。`nil` は繰り返しなし。
    /// `weekdays` は customWeekly のときだけ使う（1=日 … 7=土）。
    func next(after date: Date, weekdays: [Int] = [], calendar: Calendar = .current) -> Date? {
        switch self {
        case .none: return nil
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekdays: return nextMatching(after: date, calendar: calendar) {
            !calendar.isDateInWeekend($0)
        }
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date)
        case .customWeekly:
            let wanted = Set(weekdays)
            guard !wanted.isEmpty else { return nil }
            return nextMatching(after: date, calendar: calendar) {
                wanted.contains(calendar.component(.weekday, from: $0))
            }
        }
    }

    /// 条件に合う次の日を探す。最大1年で打ち切る（見つからない指定で無限に回さない）。
    private func nextMatching(after date: Date, calendar: Calendar,
                              _ ok: (Date) -> Bool) -> Date? {
        var d = date
        for _ in 0..<366 {
            guard let n = calendar.date(byAdding: .day, value: 1, to: d) else { return nil }
            d = n
            if ok(d) { return d }
        }
        return nil
    }
}

let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

struct Profile: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var symbol: String
    var colorHex: String
    /// 新規タスクの既定時刻（"HH:mm"）
    var defaultTime: String

    static let fallback = Profile(id: "inbox", name: "未分類",
                                  symbol: "circle.dashed", colorHex: "#8E8E93",
                                  defaultTime: "09:00")
}

struct Task: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var status: Status = .inbox
    var priority: Priority = .low
    var profileID: String
    var due: Date
    var memo: String = ""
    var repeatRule: Repeat = .none
    var createdAt: Date = Date()
    var completedAt: Date?
    /// サブタスクなら親タスクのID。カンバンでのみ入れ子表示する。
    var parentID: UUID?
    /// 時刻を決めない「その日のうちに」タスク
    var allDay: Bool = false
    /// 同じ日時の中での手動の並び順。小さいほど上。
    var manualOrder: Double = Date().timeIntervalSince1970
    /// repeatRule が customWeekly のときの曜日（1=日 … 7=土）
    var repeatWeekdays: [Int] = []

    var isSubtask: Bool { parentID != nil }

    enum CodingKeys: String, CodingKey {
        case id, title, status, priority, memo, createdAt, completedAt, parentID
        case allDay, manualOrder, repeatWeekdays
        case profileID = "profile"
        case due
        case repeatRule = "repeat"
    }

    init(id: UUID = UUID(), title: String, status: Status = .inbox,
         priority: Priority = .low, profileID: String, due: Date, memo: String = "",
         repeatRule: Repeat = .none, createdAt: Date = Date(), completedAt: Date? = nil,
         parentID: UUID? = nil, allDay: Bool = false,
         manualOrder: Double = Date().timeIntervalSince1970,
         repeatWeekdays: [Int] = []) {
        self.id = id; self.title = title; self.status = status; self.priority = priority
        self.profileID = profileID; self.due = due; self.memo = memo
        self.repeatRule = repeatRule; self.createdAt = createdAt
        self.completedAt = completedAt; self.parentID = parentID
        self.allDay = allDay; self.manualOrder = manualOrder
        self.repeatWeekdays = repeatWeekdays
    }

    /// 古い tasks.json（allDay / manualOrder が無いもの）も読めるようにする。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        status = try c.decodeIfPresent(Status.self, forKey: .status) ?? .inbox
        priority = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? .low
        profileID = try c.decode(String.self, forKey: .profileID)
        due = try c.decode(Date.self, forKey: .due)
        memo = try c.decodeIfPresent(String.self, forKey: .memo) ?? ""
        repeatRule = try c.decodeIfPresent(Repeat.self, forKey: .repeatRule) ?? .none
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
        allDay = try c.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
        manualOrder = try c.decodeIfPresent(Double.self, forKey: .manualOrder)
            ?? createdAt.timeIntervalSince1970
        repeatWeekdays = try c.decodeIfPresent([Int].self, forKey: .repeatWeekdays) ?? []
    }
}

/// tasks.json の中身そのもの。
struct Document: Codable {
    var version: Int = 1
    var profiles: [Profile]
    var tasks: [Task]

    static var starter: Document {
        Document(profiles: [
            Profile(id: "work", name: "仕事", symbol: "briefcase.fill",
                    colorHex: "#0A84FF", defaultTime: "10:00"),
            Profile(id: "study", name: "大学", symbol: "graduationcap.fill",
                    colorHex: "#FF9F0A", defaultTime: "18:00"),
            Profile(id: "dev", name: "個人開発", symbol: "chevron.left.forwardslash.chevron.right",
                    colorHex: "#30D158", defaultTime: "21:00"),
        ], tasks: [])
    }
}
