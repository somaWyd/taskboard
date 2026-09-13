import SwiftUI

/// SFシンボルをビジュアルで選ぶ。名前を打たなくていいようにする。
struct SymbolPicker: View {
    @Binding var symbol: String
    var tint: Color
    var onPick: () -> Void = {}

    @State private var query = ""

    private static let catalog: [(String, [String])] = [
        ("仕事", ["briefcase.fill", "building.2.fill", "person.2.fill", "chart.bar.fill",
                "doc.text.fill", "envelope.fill", "phone.fill", "calendar",
                "clock.fill", "checklist", "tray.full.fill", "banknote.fill"]),
        ("学び", ["graduationcap.fill", "book.fill", "books.vertical.fill", "pencil.and.ruler.fill",
                "function", "flask.fill", "atom", "brain.head.profile",
                "globe.asia.australia.fill", "text.book.closed.fill", "lightbulb.fill", "questionmark.circle.fill"]),
        ("開発", ["chevron.left.forwardslash.chevron.right", "terminal.fill", "hammer.fill",
                "wrench.and.screwdriver.fill", "cpu.fill", "externaldrive.fill",
                "server.rack", "ant.fill", "cube.fill", "gearshape.fill",
                "app.badge.fill", "square.stack.3d.up.fill"]),
        ("生活", ["house.fill", "cart.fill", "fork.knife", "bed.double.fill",
                "figure.run", "dumbbell.fill", "heart.fill", "pills.fill",
                "airplane", "car.fill", "pawprint.fill", "leaf.fill"]),
        ("その他", ["star.fill", "flag.fill", "bolt.fill", "flame.fill",
                 "bell.fill", "tag.fill", "paintpalette.fill", "camera.fill",
                 "music.note", "gamecontroller.fill", "sparkles", "circle.dashed"]),
    ]

    private var results: [(String, [String])] {
        guard !query.isEmpty else { return Self.catalog }
        let hits = Self.catalog.flatMap(\.1).filter { $0.localizedCaseInsensitiveContains(query) }
        return hits.isEmpty ? [] : [("検索結果", hits)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                TextField("シンボルを検索（英語名）", text: $query)
                    .textFieldStyle(.roundedBorder)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(results, id: \.0) { group, symbols in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(group).font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 6),
                                                     count: 8), spacing: 6) {
                                ForEach(symbols, id: \.self) { cell($0) }
                            }
                        }
                    }
                    if results.isEmpty {
                        Text("該当するシンボルがありません")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 190)
        }
    }

    private func cell(_ name: String) -> some View {
        let on = name == symbol
        return Button {
            symbol = name
            onPick()
        } label: {
            Image(systemName: name)
                .font(.system(size: 15))
                .foregroundStyle(on ? tint : .primary)
                .frame(width: 34, height: 30)
                .background(RoundedRectangle(cornerRadius: 7)
                    .fill(on ? tint.opacity(0.18) : Color.primary.opacity(0.05)))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(tint, lineWidth: on ? 1.5 : 0)
                }
        }
        .buttonStyle(.plain)
        .help(name)
    }
}
