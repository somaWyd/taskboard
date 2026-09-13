import SwiftUI

struct TaskEditor: View {
    @Environment(Store.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var task: Task
    @State private var showCalendar = false
    @State private var error: String?
    private let onSave: (Task) -> Void

    init(task: Task, onSave: @escaping (Task) -> Void) {
        _task = State(initialValue: task)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            form
            Divider()
            footer
        }
        .frame(width: 480)
    }

    private var form: some View {
        Form {
            TextField("タイトル", text: $task.title, prompt: Text("やることを書く"))
                .textFieldStyle(.roundedBorder)
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Picker("プロファイル", selection: $task.profileID) {
                ForEach(store.doc.profiles) { p in
                    Label(p.name, systemImage: p.symbol).tag(p.id)
                }
            }

            Section {
                Toggle("時間を指定しない（その日中）", isOn: $task.allDay)
                DatePicker("期限", selection: $task.due,
                           displayedComponents: task.allDay ? [.date] : [.date, .hourAndMinute])
                HStack(spacing: 6) {
                    ForEach(DefaultDue.allCases) { d in
                        Button(d.label) { setDay(d.date()) }
                    }
                    Button("カレンダー…") { showCalendar.toggle() }
                    Spacer()
                }
                .buttonStyle(.bordered).controlSize(.small)
                if showCalendar {
                    DatePicker("", selection: $task.due,
                               displayedComponents: task.allDay ? [.date] : [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
            }

            Picker("重要度", selection: $task.priority) {
                ForEach(Priority.allCases) { p in
                    Label {
                        Text(p.label)
                    } icon: {
                        Image(systemName: "circle.fill").foregroundStyle(settings.color(for: p))
                    }
                    .tag(p)
                }
            }
            Picker("ステータス", selection: $task.status) {
                ForEach(Status.allCases) { Text($0.label).tag($0) }
            }
            Picker("繰り返し", selection: $task.repeatRule) {
                ForEach(Repeat.allCases) { Text($0.label).tag($0) }
            }
            if task.repeatRule == .customWeekly {
                HStack(spacing: 6) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { i, name in
                        let on = task.repeatWeekdays.contains(i + 1)
                        Button(name) {
                            if let k = task.repeatWeekdays.firstIndex(of: i + 1) {
                                task.repeatWeekdays.remove(at: k)
                            } else {
                                task.repeatWeekdays.append(i + 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 30, height: 26)
                        .background(on ? AnyShapeStyle(.tint)
                                       : AnyShapeStyle(Color.primary.opacity(0.07)),
                                    in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(on ? Color.white : Color.primary)
                    }
                    Spacer()
                }
            }

            Section("メモ") {
                TextEditor(text: $task.memo)
                    .font(settings.uiFont)
                    .frame(height: 130)
                    .scrollContentBackground(.hidden)
                    .background(Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        HStack {
            if store.doc.tasks.contains(where: { $0.id == task.id }) {
                Button("削除", role: .destructive) {
                    store.delete(task)
                    dismiss()
                }
            }
            Spacer()
            Button("キャンセル", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("保存") { submit() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(14)
    }

    private func setDay(_ day: Date) {
        let cal = settings.calendar
        let time = cal.dateComponents([.hour, .minute], from: task.due)
        task.due = cal.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0,
                            second: 0, of: day) ?? day
    }

    private func submit() {
        guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "タイトルを入力してください"
            return
        }
        error = nil
        onSave(task)
        dismiss()
    }
}
