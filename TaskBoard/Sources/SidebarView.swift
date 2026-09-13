import SwiftUI

struct SidebarView: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var state
    @Environment(AppSettings.self) private var settings

    @State private var editing: Profile?
    @State private var dropTarget: String?
    @State private var hovered: String?

    var body: some View {
        @Bindable var settings = settings
        return List {
            Section("期間") {
                ForEach(settings.orderedPeriods) { period in
                    periodRow(period)
                        .draggable("period:" + period.rawValue) {
                            dragPreview(period.label, symbol: period.symbol, tint: .secondary)
                        }
                        .dropDestination(for: String.self) { items, _ in
                            movePeriod(items, before: period)
                        } isTargeted: { over in
                            dropTarget = over ? "period:" + period.rawValue : nil
                        }
                }
            }
            Section("プロファイル") {
                ForEach(store.doc.profiles) { profile in
                    profileRow(profile)
                        .draggable("profile:" + profile.id) {
                            dragPreview(profile.name, symbol: profile.symbol,
                                        tint: Color(hex: profile.colorHex))
                        }
                        .dropDestination(for: String.self) { items, _ in
                            moveProfile(items, before: profile)
                        } isTargeted: { over in
                            dropTarget = over ? "profile:" + profile.id : nil
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 30)
        .sheet(item: $editing) { profile in
            ProfileEditor(profile: profile)
        }
    }

    // MARK: - 行

    private func periodRow(_ period: Period) -> some View {
        let on = state.period == period
        // Button にすると List の並べ替えドラッグを奪われるので、素の行＋タップにする
        return HStack(spacing: 9) {
            Image(systemName: period.symbol)
                .foregroundStyle(on ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .frame(width: 18)
            Text(period.label)
            Spacer()
            Text("\(count(period))")
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.vertical, 3).padding(.horizontal, 7)
        .background(selectionGlow(on))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Motion.quick) { state.period = period } }
        .overlay(alignment: .top) { insertionLine("period:" + period.rawValue) }
        .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
    }

    private func profileRow(_ profile: Profile) -> some View {
        let on = state.activeProfiles.isEmpty || state.activeProfiles.contains(profile.id)
        let isDefault = settings.defaultProfileID == profile.id
        return HStack(spacing: 9) {
            Image(systemName: profile.symbol)
                .foregroundStyle(Color(hex: profile.colorHex))
                .frame(width: 18, height: 18)
                .padding(2)
                .overlay {
                    // 既定のプロファイルだけ、同じ色の枠で囲う
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(hex: profile.colorHex),
                                      lineWidth: isDefault ? 1.5 : 0)
                }
            Text(profile.name).lineLimit(1)
            if isDefault {
                Text("デフォルト").font(.caption).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            if hovered == profile.id {
                Menu {
                    profileMenu(profile)
                } label: {
                    Image(systemName: "ellipsis").font(.caption)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(.secondary)

                Button {
                    withAnimation(Motion.quick) { toggle(profile.id) }
                } label: {
                    Image(systemName: on ? "eye" : "eye.slash").font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(on ? "このプロファイルを隠す" : "表示する")
            } else {
                Text("\(profileCount(profile.id))")
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 7)
        .background(selectionGlow(on))
        .opacity(on ? 1 : 0.42)
        .contentShape(Rectangle())
        .onHover { over in hovered = over ? profile.id : (hovered == profile.id ? nil : hovered) }
        .onTapGesture { withAnimation(Motion.quick) { toggle(profile.id) } }
        .contextMenu { profileMenu(profile) }
        .overlay(alignment: .top) { insertionLine("profile:" + profile.id) }
        .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
    }

    @ViewBuilder
    private func profileMenu(_ profile: Profile) -> some View {
        Button("「\(profile.name)」を編集…") { editing = profile }
        Button("デフォルトにする") { settings.defaultProfileID = profile.id }
            .disabled(settings.defaultProfileID == profile.id)
        Button("このプロファイルだけ表示") { state.activeProfiles = [profile.id] }
        Button("すべて表示") { state.activeProfiles = [] }
        Divider()
        Button("プロファイルを追加…") { editing = newProfile() }
        Button("削除", role: .destructive) { remove(profile) }
            .disabled(store.doc.profiles.count <= 1)
    }

    /// 選択はチェックマークではなく淡いグレーの発光で示す。
    private func selectionGlow(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Color.primary.opacity(on ? 0.10 : 0))
            .shadow(color: .primary.opacity(on ? 0.14 : 0), radius: 5)
    }

    @ViewBuilder
    private func insertionLine(_ key: String) -> some View {
        if dropTarget == key {
            Capsule().fill(.tint).frame(height: 2).padding(.horizontal, 4)
        }
    }

    private func dragPreview(_ text: String, symbol: String, tint: Color) -> some View {
        Label(text, systemImage: symbol)
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.background, in: RoundedRectangle(cornerRadius: 7))
    }

    /// ドロップされた行の位置へ差し込む。別セクションからの取り違えは弾く。
    private func movePeriod(_ items: [String], before target: Period) -> Bool {
        guard let raw = items.first(where: { $0.hasPrefix("period:") })?
                .replacingOccurrences(of: "period:", with: ""),
              raw != target.rawValue else { return false }
        var order = settings.orderedPeriods.map(\.rawValue)
        guard let from = order.firstIndex(of: raw) else { return false }
        order.remove(at: from)
        let to = order.firstIndex(of: target.rawValue) ?? order.count
        order.insert(raw, at: to)
        withAnimation(Motion.quick) { settings.sidebarOrder = order }
        dropTarget = nil
        return true
    }

    private func moveProfile(_ items: [String], before target: Profile) -> Bool {
        guard let id = items.first(where: { $0.hasPrefix("profile:") })?
                .replacingOccurrences(of: "profile:", with: ""),
              id != target.id,
              let from = store.doc.profiles.firstIndex(where: { $0.id == id })
        else { return false }
        let moved = store.doc.profiles.remove(at: from)
        let to = store.doc.profiles.firstIndex(where: { $0.id == target.id })
            ?? store.doc.profiles.count
        store.doc.profiles.insert(moved, at: to)
        store.save()
        dropTarget = nil
        return true
    }

    // MARK: - 操作

    private func newProfile() -> Profile {
        let p = Profile(id: "profile-\(UUID().uuidString.prefix(6))", name: "新しいプロファイル",
                        symbol: "folder.fill", colorHex: "#0A84FF", defaultTime: "09:00")
        store.doc.profiles.append(p)
        store.save()
        return p
    }

    private func remove(_ profile: Profile) {
        guard store.doc.profiles.count > 1 else { return }
        store.doc.profiles.removeAll { $0.id == profile.id }
        state.activeProfiles.remove(profile.id)
        store.save()
    }

    /// プロファイルは「全部オン」を空集合で表す。最後の1つは消さない。
    /// 全部オンの状態から押したときだけ、そのプロファイルだけの表示に切り替える。
    private func toggle(_ id: String) {
        guard !state.activeProfiles.isEmpty else {
            state.activeProfiles = [id]
            return
        }
        var active = state.activeProfiles
        if active.contains(id) {
            guard active.count > 1 else { return }
            active.remove(id)
        } else {
            active.insert(id)
        }
        state.activeProfiles = active.count == store.doc.profiles.count ? [] : active
    }

    private func count(_ period: Period) -> Int {
        filter(period: period, profiles: state.activeProfiles).count(store.doc.tasks)
    }

    private func profileCount(_ id: String) -> Int {
        filter(period: state.period, profiles: [id]).count(store.doc.tasks)
    }

    private func filter(period: Period, profiles: Set<String>) -> Filter {
        Filter(period: period, profileIDs: profiles, calendar: settings.calendar,
               sort: settings.sortRule, profileOrder: store.doc.profiles.map(\.id))
    }
}

/// サイドバーの右クリックから開く、プロファイル1件の編集シート。
struct ProfileEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Profile
    @State private var error: String?

    init(profile: Profile) { _draft = State(initialValue: profile) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                TextField("名称", text: $draft.name)
                LabeledContent("色") { Swatches(selection: $draft.colorHex) }
                TextField("既定の時刻（HH:mm）", text: $draft.defaultTime)
                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Section("アイコン") {
                    SymbolPicker(symbol: $draft.symbol, tint: Color(hex: draft.colorHex))
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("キャンセル", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 460)
    }

    private func save() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { error = "名称を入力してください"; return }
        guard isValidTime(draft.defaultTime) else {
            error = "既定の時刻は HH:mm で入力してください（例 09:30）"
            return
        }
        draft.name = name
        if let i = store.doc.profiles.firstIndex(where: { $0.id == draft.id }) {
            store.doc.profiles[i] = draft
        } else {
            store.doc.profiles.append(draft)
        }
        store.save()
        dismiss()
    }

    private func isValidTime(_ s: String) -> Bool {
        let parts = s.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return false }
        return (0...23).contains(h) && (0...59).contains(m)
    }
}
