import SwiftUI
import Observation

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "システム"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum PriorityStyle: String, CaseIterable, Identifiable {
    case bar, dot, text
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bar: return "左の帯"
        case .dot: return "ドット"
        case .text: return "文字色"
        }
    }
}

enum DefaultDue: String, CaseIterable, Identifiable {
    case today, tomorrow, dayAfter, weekend
    var id: String { rawValue }
    var label: String {
        switch self {
        case .today: return "今日"
        case .tomorrow: return "明日"
        case .dayAfter: return "明後日"
        case .weekend: return "今週末"
        }
    }
    func date(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .today: return now
        case .tomorrow: return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        case .dayAfter: return calendar.date(byAdding: .day, value: 2, to: now) ?? now
        case .weekend:
            return calendar.nextDate(after: now, matching: DateComponents(weekday: 7),
                                     matchingPolicy: .nextTime) ?? now
        }
    }
}

enum Surface: String, CaseIterable, Identifiable {
    case matte, glass
    var id: String { rawValue }
    var label: String { self == .matte ? "マット" : "リキッドグラス" }
    var note: String {
        self == .matte ? "均一な塗り。文字のコントラストが安定する"
                       : "背景が透ける。奥行きが出るぶん contrast は落ちる"
    }
}

enum CardTint: String, CaseIterable, Identifiable {
    case badge, fill, edge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .badge: return "バッジのみ"
        case .fill: return "カード全体を淡く"
        case .edge: return "枠線とバッジ"
        }
    }
}

@Observable
final class AppSettings {
    var surface: Surface { didSet { put(surface.rawValue, "surface") } }
    var sortRule: SortRule { didSet { put(sortRule.rawValue, "sortRule") } }
    var cardTint: CardTint { didSet { put(cardTint.rawValue, "cardTint") } }
    var tintStrength: Double { didSet { put(tintStrength, "tintStrength") } }
    var sidebarOrder: [String] { didSet { put(sidebarOrder, "sidebarOrder2") } }
    var appearance: Appearance { didSet { put(appearance.rawValue, "appearance") } }
    var accentHex: String { didSet { put(accentHex, "accentHex") } }
    var fontName: String { didSet { put(fontName, "fontName") } }      // "" = システム
    var fontSize: Double { didSet { put(fontSize, "fontSize") } }
    var weekStartsMonday: Bool { didSet { put(weekStartsMonday, "weekStartsMonday") } }
    var showDoneColumn: Bool { didSet { put(showDoneColumn, "showDoneColumn") } }
    var doneRetentionDays: Int { didSet { put(doneRetentionDays, "doneRetentionDays") } }

    var priorityHex: [Int: String] {
        didSet { priorityHex.forEach { put($1, "priority\($0)Hex") } }
    }
    var priorityStyle: PriorityStyle { didSet { put(priorityStyle.rawValue, "priorityStyle") } }
    var defaultPriority: Priority { didSet { put(defaultPriority.rawValue, "defaultPriority") } }
    var defaultDue: DefaultDue { didSet { put(defaultDue.rawValue, "defaultDue") } }
    var defaultProfileID: String { didSet { put(defaultProfileID, "defaultProfileID") } }
    var defaultStatus: Status { didSet { put(defaultStatus.rawValue, "defaultStatus") } }
    /// 時刻を決めずに作ったタスクは終日として記録する
    var defaultAllDay: Bool { didSet { put(defaultAllDay, "defaultAllDay") } }

    static let defaultPriorityHex: [Int: String] = [1: "#8E8E93", 2: "#FFCC00", 3: "#FF3B30"]

    init() {
        let d = UserDefaults.standard
        surface = Surface(rawValue: d.string(forKey: "surface") ?? "") ?? .matte
        sortRule = SortRule(rawValue: d.string(forKey: "sortRule") ?? "") ?? .dateManual
        cardTint = CardTint(rawValue: d.string(forKey: "cardTint") ?? "") ?? .badge
        tintStrength = d.object(forKey: "tintStrength") as? Double ?? 0.14
        sidebarOrder = d.stringArray(forKey: "sidebarOrder2") ?? Period.allCases.map(\.rawValue)
        appearance = Appearance(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        accentHex = d.string(forKey: "accentHex") ?? "#0A84FF"
        fontName = d.string(forKey: "fontName") ?? ""
        fontSize = d.object(forKey: "fontSize") as? Double ?? 13
        weekStartsMonday = d.bool(forKey: "weekStartsMonday")
        showDoneColumn = d.object(forKey: "showDoneColumn") as? Bool ?? true
        doneRetentionDays = d.object(forKey: "doneRetentionDays") as? Int ?? 7
        priorityHex = Self.defaultPriorityHex.reduce(into: [:]) { acc, kv in
            acc[kv.key] = d.string(forKey: "priority\(kv.key)Hex") ?? kv.value
        }
        priorityStyle = PriorityStyle(rawValue: d.string(forKey: "priorityStyle") ?? "") ?? .bar
        defaultPriority = Priority(rawValue: d.integer(forKey: "defaultPriority")) ?? .low
        defaultDue = DefaultDue(rawValue: d.string(forKey: "defaultDue") ?? "") ?? .today
        defaultProfileID = d.string(forKey: "defaultProfileID") ?? ""
        defaultStatus = Status(rawValue: d.string(forKey: "defaultStatus") ?? "") ?? .inbox
        defaultAllDay = d.object(forKey: "defaultAllDay") as? Bool ?? true
    }

    /// 保存順にならべた期間タブ。未知・欠落があっても既定順で補う。
    var orderedPeriods: [Period] {
        let known = sidebarOrder.compactMap(Period.init(rawValue:))
        let missing = Period.allCases.filter { !known.contains($0) }
        return known + missing
    }

    func color(for p: Priority) -> Color {
        Color(hex: priorityHex[p.rawValue] ?? AppSettings.defaultPriorityHex[p.rawValue]!)
    }

    var accent: Color { Color(hex: accentHex) }

    var uiFont: Font {
        fontName.isEmpty ? .system(size: fontSize)
                         : .custom(fontName, size: fontSize, relativeTo: .body)
    }

    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ja_JP")
        c.firstWeekday = weekStartsMonday ? 2 : 1
        return c
    }

    private func put(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let v = UInt64(s, radix: 16) ?? 0x8E8E93
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

/// 設定で選べる色（プロファイル・重要度・アクセント共通）
let paletteHexes = ["#8E8E93", "#0A84FF", "#30D158", "#FFCC00",
                    "#FF9F0A", "#FF3B30", "#BF5AF2", "#64D2FF"]
