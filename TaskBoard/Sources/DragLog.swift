import Foundation

/// ドラッグの判定を後から検証するための記録。
/// `defaults write dev.soma.taskboard dragDebug -bool YES` のときだけ書き出す。
enum DragLog {
    private static var enabled: Bool { UserDefaults.standard.bool(forKey: "dragDebug") }
    private static let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("taskboard-drag.log")

    static func begin(_ drag: BoardDrag, cardFramesCount: Int, start: CGPoint) {
        guard enabled else { return }
        var lines = ["--- 開始 \(stamp()) ---",
                     "掴んだ点: \(fmt(start))  掴んだタスク: \(drag.task.title)",
                     "収集済みカード枠: \(cardFramesCount)"]
        for (status, rect) in drag.columns.sorted(by: { $0.value.minX < $1.value.minX }) {
            let rows = drag.order[status] ?? []
            lines.append("  列 \(status.rawValue): \(fmt(rect)) / 判定対象 \(rows.count)件")
            for r in rows {
                lines.append("    \(fmt(r.frame)) 親可:\(r.canBeParent)")
            }
        }
        append(lines)
    }

    static func end(_ drag: BoardDrag?, at point: CGPoint) {
        guard enabled else { return }
        guard let drag else { append(["--- 終了 スナップショット無し ---"]); return }
        append(["離した点: \(fmt(point))  判定: \(String(describing: drag.drop(at: point)))", ""])
    }

    private static func append(_ lines: [String]) {
        let text = lines.joined(separator: "\n") + "\n"
        guard let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    private static func fmt(_ r: CGRect) -> String {
        String(format: "x%.0f..%.0f y%.0f..%.0f", r.minX, r.maxX, r.minY, r.maxY)
    }
    private static func fmt(_ p: CGPoint) -> String { String(format: "(%.0f, %.0f)", p.x, p.y) }
    private static func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
