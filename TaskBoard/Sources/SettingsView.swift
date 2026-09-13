import SwiftUI
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("一般", systemImage: "gearshape") }
            DisplaySettings().tabItem { Label("表示", systemImage: "square.grid.2x2") }
            ProfileSettings().tabItem { Label("プロファイル", systemImage: "person.2") }
            PrioritySettings().tabItem { Label("重要度", systemImage: "flag") }
            DefaultsSettings().tabItem { Label("既定値", systemImage: "clock") }
            MarkdownSettings().tabItem { Label("MD出力", systemImage: "doc.plaintext") }
            StorageSettings().tabItem { Label("詳細", systemImage: "folder") }
        }
        .frame(width: 620)
        .padding(20)
    }
}

// MARK: - 一般

struct GeneralSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Picker("外観", selection: $settings.appearance) {
                ForEach(Appearance.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            LabeledContent("アクセントカラー") {
                Swatches(selection: $settings.accentHex)
            }

            Picker("フォント", selection: $settings.fontName) {
                Text("システム標準").tag("")
                Divider()
                ForEach(fontFamilies, id: \.self) { Text($0).tag($0) }
            }
            LabeledContent("文字サイズ") {
                HStack {
                    Slider(value: $settings.fontSize, in: 11...18, step: 1)
                    Text("\(Int(settings.fontSize))pt").monospacedDigit()
                }
            }
            LabeledContent("プレビュー") {
                Text("定例MTGの資料を共有 / Task 123")
                    .font(settings.uiFont)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            }

            Section {
                Picker("質感", selection: $settings.surface) {
                    ForEach(Surface.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(settings.surface.note).font(.caption).foregroundStyle(.secondary)
                Toggle("週の始まりを月曜にする", isOn: $settings.weekStartsMonday)
            }
        }
        .formStyle(.grouped)
    }

    private var fontFamilies: [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }
}

// MARK: - 表示

struct DisplaySettings: View {
    @Environment(Store.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("並び順") {
                Picker("既定の並び", selection: $settings.sortRule) {
                    ForEach(SortRule.allCases) { Text($0.label).tag($0) }
                }
                Text("カンバン・カレンダー・MD出力のすべてに効きます。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("タスクにプロファイル色をどう出すか") {
                Picker("配色", selection: $settings.cardTint) {
                    ForEach(CardTint.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if settings.cardTint == .fill {
                    LabeledContent("濃さ") {
                        HStack {
                            Slider(value: $settings.tintStrength, in: 0.05...0.30)
                            Text(String(format: "%.0f%%", settings.tintStrength * 100))
                                .monospacedDigit().font(.caption)
                        }
                    }
                }
                preview
            }

            Section("カンバン") {
                Toggle("Done列を表示する", isOn: $settings.showDoneColumn)
                Picker("Done列に残す期間", selection: $settings.doneRetentionDays) {
                    Text("完了したらすぐ隠す").tag(0)
                    Text("1日").tag(1)
                    Text("7日").tag(7)
                    Text("30日").tag(30)
                    Text("すべて残す").tag(-1)
                }
                .disabled(!settings.showDoneColumn)
                Text("期間を過ぎた完了タスクはサイドバーの「完了済」にリストで並びます（削除はされません）。")
                    .font(.caption).foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
    }

    /// 実物のカードをそのまま並べて見せる。説明文より速い。
    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(samples) { CardView(task: $0) }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var samples: [Task] {
        let profiles = store.doc.profiles
        let now = Date()
        return profiles.prefix(3).enumerated().map { i, p in
            Task(title: ["定例MTGの資料を共有", "レポートの参考文献を集める", "画面設計を固める"][i % 3],
                 status: .next, priority: Priority(rawValue: 3 - i) ?? .low,
                 profileID: p.id, due: now,
                 memo: i == 0 ? "決定事項と宿題を分ける" : "")
        }
    }
}

// MARK: - プロファイル

struct ProfileSettings: View {
    @Environment(Store.self) private var store
    @State private var selection: String?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(store.doc.profiles) { p in
                    HStack {
                        Image(systemName: p.symbol).foregroundStyle(Color(hex: p.colorHex))
                        Text(p.name)
                        Spacer()
                        Text("既定 \(p.defaultTime)").font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(p.id)
                }
                .onMove { store.doc.profiles.move(fromOffsets: $0, toOffset: $1); store.save() }
            }
            .frame(height: 140)

            HStack(spacing: 4) {
                Button { addProfile() } label: { Image(systemName: "plus") }
                Button { removeSelected() } label: { Image(systemName: "minus") }
                    .disabled(selection == nil || store.doc.profiles.count <= 1)
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(6)

            Divider()
            if let index = store.doc.profiles.firstIndex(where: { $0.id == selection }) {
                editor(index)
            } else {
                Text("編集するプロファイルを選んでください")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 420)
    }

    private func editor(_ index: Int) -> some View {
        @Bindable var store = store
        let tint = Color(hex: store.doc.profiles[index].colorHex)
        return Form {
            TextField("名称", text: $store.doc.profiles[index].name)
                .onSubmit { store.save() }
            LabeledContent("色") {
                Swatches(selection: $store.doc.profiles[index].colorHex) { store.save() }
            }
            TextField("既定の時刻（HH:mm）", text: $store.doc.profiles[index].defaultTime)
                .onSubmit { store.save() }
            Section("アイコン") {
                SymbolPicker(symbol: $store.doc.profiles[index].symbol,
                             tint: tint) { store.save() }
            }
        }
        .formStyle(.grouped)
    }

    private func addProfile() {
        let id = "profile-\(UUID().uuidString.prefix(6))"
        store.doc.profiles.append(Profile(id: id, name: "新しいプロファイル",
                                          symbol: "folder", colorHex: "#0A84FF",
                                          defaultTime: "09:00"))
        store.save()
        selection = id
    }

    private func removeSelected() {
        guard let selection, store.doc.profiles.count > 1 else { return }
        store.doc.profiles.removeAll { $0.id == selection }
        store.save()
        self.selection = nil
    }
}

// MARK: - 重要度

struct PrioritySettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            ForEach(Priority.allCases) { p in
                LabeledContent(p.label) {
                    Swatches(selection: Binding(
                        get: { settings.priorityHex[p.rawValue] ?? "#8E8E93" },
                        set: { settings.priorityHex[p.rawValue] = $0 }))
                }
            }
            Picker("色の出し方", selection: $settings.priorityStyle) {
                ForEach(PriorityStyle.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Section {
                Button("既定の色に戻す") {
                    settings.priorityHex = AppSettings.defaultPriorityHex
                }
            } footer: {
                Text("色はカンバン・カレンダー・ウィジェットのすべてに反映されます。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 既定値

struct DefaultsSettings: View {
    @Environment(Store.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("新規タスクの期限", selection: $settings.defaultDue) {
                    ForEach(DefaultDue.allCases) { Text($0.label).tag($0) }
                }
                Picker("既定プロファイル", selection: $settings.defaultProfileID) {
                    Text("先頭のプロファイル").tag("")
                    ForEach(store.doc.profiles) { Text($0.name).tag($0.id) }
                }
                Picker("既定ステータス", selection: $settings.defaultStatus) {
                    ForEach([Status.inbox, .next]) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("時刻を決めずに作ったタスクは終日にする", isOn: $settings.defaultAllDay)
                Picker("既定の重要度", selection: $settings.defaultPriority) {
                    ForEach(Priority.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("終日をやめて時刻を入れると、プロファイルごとの「既定の時刻」が入ります。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - MD出力

struct MarkdownSettings: View {
    @Environment(Store.self) private var store
    @State private var options = MDOptions()

    var body: some View {
        Form {
            Picker("対象期間", selection: $options.period) {
                ForEach(Period.allCases) { Text($0.label).tag($0) }
            }
            Picker("グループ化", selection: $options.group) {
                ForEach(MDGroup.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("期限を含める", isOn: $options.includeDue)
            Toggle("重要度を含める", isOn: $options.includePriority)
            Toggle("プロファイルを含める", isOn: $options.includeProfile)
            Toggle("メモを含める", isOn: $options.includeMemo)
            Toggle("完了タスクを含める", isOn: $options.includeDone)

            Section {
                ScrollView {
                    Text(preview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 150)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                Button("クリップボードにコピー") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(preview, forType: .string)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var preview: String { Markdown.render(store.doc, options: options) }
}

// MARK: - 詳細（保存先）

struct StorageSettings: View {
    @Environment(Store.self) private var store

    var body: some View {
        Form {
            LabeledContent("保存先") {
                Text(store.folder?.path ?? "未設定")
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("フォルダを変更…") { pick() }
                Button("Finderで表示") {
                    if let f = store.folder { NSWorkspace.shared.open(f) }
                }
                .disabled(store.folder == nil)
                Button("再読み込み") { store.load() }
            }
            Section {
                Text("tasks.json が正のデータです。tasks.md は保存のたびに書き出される読み取り用のコピーで、編集しても取り込まれません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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

// MARK: - 色見本

struct Swatches: View {
    @Binding var selection: String
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            ForEach(paletteHexes, id: \.self) { hex in
                let on = hex.caseInsensitiveCompare(selection) == .orderedSame
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: hex))
                    .frame(width: 24, height: 24)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.tint, lineWidth: on ? 2.5 : 0)
                    }
                    .onTapGesture { selection = hex; onChange() }
                    .accessibilityLabel(hex)
            }
        }
    }
}
