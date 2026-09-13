import SwiftUI

/// カンバン1枚のカード。要素をクリックするとその場で直せる。
/// まとめて直したいときは右クリック →「編集…」でシートを開く。
struct CardView: View {
    @Environment(Store.self) private var store
    @Environment(AppSettings.self) private var settings

    let task: Task
    var selected = false
    var ghost = false
    var isSubtask = false
    var onToggle: (() -> Void)?
    var onAddSubtask: (() -> Void)?

    @State private var titleDraft = ""
    @State private var showCalendar = false
    @State private var memoDraft = ""
    @FocusState private var field: Field?

    private enum Field: Hashable { case title, memo }

    private var profile: Profile { store.profile(task.profileID) }
    private var tint: Color { Color(hex: profile.colorHex) }
    private var priorityColor: Color { settings.color(for: task.priority) }
    private var subtasks: [Task] { store.subtasks(of: task) }
    /// ゴースト表示中は編集させない
    private var editable: Bool { !ghost }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if settings.priorityStyle == .bar && !isSubtask {
                priorityBar
            }
            VStack(alignment: .leading, spacing: 7) {
                titleRow
                memoRow
                if !isSubtask || !task.memo.isEmpty || task.repeatRule != .none { metaRow }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: isSubtask ? 52 : 60)
        }
        .background {
            if settings.cardTint == .fill {
                RoundedRectangle(cornerRadius: 10).fill(tint.opacity(settings.tintStrength))
            }
        }
        .panel(settings.surface, radius: 10, elevated: true)
        .hairline(10, color: borderColor,
                  width: selected ? 2 : (settings.cardTint == .edge ? 1 : 0.5))
        .shadow(color: .black.opacity(ghost ? 0.28 : 0.06), radius: ghost ? 14 : 1, y: ghost ? 8 : 1)
        .opacity(task.status == .done && !ghost ? 0.62 : 1)
    }

    // MARK: - 重要度

    private var priorityBar: some View {
        Menu {
            priorityItems
        } label: {
            Rectangle().fill(priorityColor).frame(width: 4)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 4)
        .disabled(!editable)
        .help("重要度")
    }

    @ViewBuilder
    private var priorityItems: some View {
        ForEach(Priority.allCases) { p in
            Button {
                var t = task; t.priority = p; store.upsert(t)
            } label: {
                Label(p.label, systemImage: task.priority == p ? "checkmark.circle.fill" : "circle")
            }
        }
    }

    // MARK: - タイトル

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if let onToggle {
                Button { withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) { onToggle() } } label: {
                    Image(systemName: task.status == .done
                          ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(task.status == .done ? AnyShapeStyle(.tint)
                                                              : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)
            }
            if settings.priorityStyle == .dot || (isSubtask && task.priority != .low) {
                Menu { priorityItems } label: {
                    Circle().fill(priorityColor).frame(width: 8, height: 8)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .tint(priorityColor)
                .disabled(!editable)
            }

            if field == .title {
                TextField("タイトル", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: isSubtask ? settings.fontSize : settings.fontSize + 1))
                    .focused($field, equals: .title)
                    .onSubmit { commitTitle() }
                    .onExitCommand { field = nil }
            } else {
                Text(task.title.isEmpty ? "（無題）" : task.title)
                    .font(.system(size: isSubtask ? settings.fontSize : settings.fontSize + 1))
                    .foregroundStyle(settings.priorityStyle == .text ? priorityColor : .primary)
                    .strikethrough(task.status == .done)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { beginTitle() }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - メモ

    @ViewBuilder
    private var memoRow: some View {
        if field == .memo {
            TextField("メモ", text: $memoDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: settings.fontSize - 1))
                .lineLimit(1...4)
                .focused($field, equals: .memo)
                .onSubmit { commitMemo() }
                .onExitCommand { field = nil }
                .padding(.leading, 8)
                .overlay(alignment: .leading) { Capsule().fill(.tint).frame(width: 2) }
        } else if !task.memo.isEmpty {
            Text(task.memo)
                .font(.system(size: settings.fontSize - 1))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.leading, 8)
                .overlay(alignment: .leading) { Capsule().fill(.quaternary).frame(width: 2) }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { beginMemo() }
        }
    }

    // MARK: - メタ行

    private var metaRow: some View {
        HStack(alignment: .center, spacing: 7) {
            profileBadge
            dueMenu
            repeatMenu
            memoButton
            if !subtasks.isEmpty {
                Text("\(subtasks.filter { $0.status == .done }.count)/\(subtasks.count)")
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let onAddSubtask {
                Button(action: onAddSubtask) {
                    Image(systemName: "text.append").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
                .help("サブタスクを追加")
            }
        }
    }

    private var profileBadge: some View {
        Menu {
            ForEach(store.doc.profiles) { p in
                Button {
                    var t = task; t.profileID = p.id; store.upsert(t)
                } label: { Label(p.name, systemImage: p.symbol) }
            }
        } label: {
            Label(profile.name, systemImage: profile.symbol)
                .font(.caption)
                .foregroundStyle(settings.cardTint == .fill ? Color.secondary : tint)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(
                    Capsule().fill(settings.cardTint == .fill
                                   ? AnyShapeStyle(Color.primary.opacity(0.07))
                                   : AnyShapeStyle(tint.opacity(0.16)))
                )
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .tint(settings.cardTint == .fill ? Color.secondary : tint)
        .disabled(!editable)
    }

    private var dueMenu: some View {
        Menu {
            ForEach(DefaultDue.allCases) { d in
                Button(d.label) { setDay(d.date()) }
            }
            Divider()
            Button(task.allDay ? "時刻を決める（09:00）" : "時間を指定しない（その日中）") {
                var t = task
                t.allDay.toggle()
                if !t.allDay {
                    t.due = settings.calendar.date(bySettingHour: 9, minute: 0,
                                                   second: 0, of: t.due) ?? t.due
                }
                store.upsert(t)
            }
            if !task.allDay {
                Divider()
                ForEach([9, 12, 15, 18, 21], id: \.self) { hour in
                    Button(String(format: "%02d:00", hour)) { setHour(hour) }
                }
            }
            Divider()
            Button("カレンダーから選ぶ…") { showCalendar = true }
        } label: {
            Text(dueText).font(.caption).foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .tint(Color.secondary)
        .disabled(!editable)
        .popover(isPresented: $showCalendar) {
            DatePicker("期限", selection: Binding(
                get: { task.due },
                set: { newValue in var t = task; t.due = newValue; store.upsert(t) }),
                displayedComponents: task.allDay ? [.date] : [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(12)
                .frame(width: 300)
        }
    }

    private var repeatMenu: some View {
        Menu {
            ForEach(Repeat.allCases) { r in
                if r == .customWeekly {
                    Menu(r.label) {
                        ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { i, name in
                            Button {
                                toggleWeekday(i + 1)
                            } label: {
                                Label(name, systemImage: task.repeatWeekdays.contains(i + 1)
                                      ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                } else {
                    Button {
                        var t = task; t.repeatRule = r
                        if r != .customWeekly { t.repeatWeekdays = [] }
                        store.upsert(t)
                    } label: {
                        Label(r.label, systemImage: task.repeatRule == r
                              ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "repeat").font(.caption)
                if task.repeatRule == .customWeekly, !task.repeatWeekdays.isEmpty {
                    Text(task.repeatWeekdays.sorted().map { weekdaySymbols[$0 - 1] }.joined())
                        .font(.caption)
                }
            }
            .foregroundStyle(task.repeatRule == .none ? AnyShapeStyle(.tertiary)
                                                      : AnyShapeStyle(Color.secondary))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .tint(Color.secondary)
        .disabled(!editable)
        .help("繰り返し")
    }

    private func toggleWeekday(_ day: Int) {
        var t = task
        t.repeatRule = .customWeekly
        if let i = t.repeatWeekdays.firstIndex(of: day) { t.repeatWeekdays.remove(at: i) }
        else { t.repeatWeekdays.append(day) }
        if t.repeatWeekdays.isEmpty { t.repeatRule = .none }
        store.upsert(t)
    }

    @ViewBuilder
    private var memoButton: some View {
        if !task.memo.isEmpty || field == .memo {
            Button { beginMemo() } label: {
                Image(systemName: "note.text").font(.caption)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        } else {
            Button { beginMemo() } label: {
                Image(systemName: "note").font(.caption)
            }
            .buttonStyle(.plain).foregroundStyle(.tertiary)
            .help("メモを書く")
        }
    }

    // MARK: - 編集の開始と確定

    private func beginTitle() {
        guard editable else { return }
        titleDraft = task.title
        field = .title
    }

    private func commitTitle() {
        let name = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        field = nil
        guard !name.isEmpty, name != task.title else { return }
        var t = task; t.title = name; store.upsert(t)
    }

    private func beginMemo() {
        guard editable else { return }
        memoDraft = task.memo
        field = .memo
    }

    private func commitMemo() {
        field = nil
        guard memoDraft != task.memo else { return }
        var t = task; t.memo = memoDraft; store.upsert(t)
    }

    private func setDay(_ day: Date) {
        let cal = settings.calendar
        let time = cal.dateComponents([.hour, .minute], from: task.due)
        var t = task
        t.due = cal.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0,
                         second: 0, of: day) ?? day
        store.upsert(t)
    }

    private func setHour(_ hour: Int) {
        var t = task
        t.due = settings.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: task.due)
            ?? task.due
        store.upsert(t)
    }

    private var borderColor: Color {
        if selected { return .accentColor }
        if settings.cardTint == .edge { return tint.opacity(0.55) }
        return .clear
    }

    private var dueText: String {
        let cal = settings.calendar
        let today = cal.isDateInToday(task.due)
        if task.allDay { return today ? "今日" : fmt("MM/dd").string(from: task.due) }
        return (today ? "今日 " : "") + fmt(today ? "HH:mm" : "MM/dd HH:mm").string(from: task.due)
    }

    private func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = pattern
        return f
    }
}
