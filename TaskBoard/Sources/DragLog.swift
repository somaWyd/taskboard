import Foundation

/// ドラッグの判定を後から検証するための記録。
/// `defaults write dev.soma.taskboard dragDebug -bool YES` のときだけ書き出す。
enum DragLog {
    private static var enabled: Bool { UserDefaults.standard.bool(forKey: "dragDebug") }
    private static let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("taskboard-drag.log")

    static func begin(_ drag: BoardDrag, missingFrames: Int, boardSize: CGSize,
                      start: CGPoint) {
        guard enabled else { return }
        var lines = ["--- 開始 \(stamp()) ---",
                     "掴んだ点: \(fmt(start))  掴んだタスク: \(drag.task.title)",
                     String(format: "盤面の大きさ: %.0f x %.0f", boardSize.width, boardSize.height),
                     "座標が取れなかった行: \(missingFrames)"]
        for (status, rect) in drag.columns.sorted(by: { $0.value.minX < $1.value.minX }) {
            let rows = drag.order[status] ?? []
            lines.append("  列 \(status.rawValue): \(fmt(rect)) / 判定対象 \(rows.count)件")
            for r in rows {
                // カードが列からはみ出していたら、どちらかの座標が古い。
                // 今回の不具合はこれを見落として長引いた。
                let inside = rect.insetBy(dx: -2, dy: -2).contains(CGPoint(x: r.frame.midX,
                                                                          y: r.frame.midY))
                lines.append("    \(fmt(r.frame)) 親可:\(r.canBeParent)"
                             + (inside ? "" : "  ← 列からはみ出している（座標の不一致）"))
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
