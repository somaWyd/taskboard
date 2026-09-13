import SwiftUI

/// ドラッグ開始時に一度だけ取る盤面のスナップショット。
/// 描画のたびに変わるフレームを参照し続けると判定がぶれるため、開始時の配置で通す。
struct BoardDrag {
    let task: Task
    /// 掴んだ位置とカード中心のずれ。ゴーストを指の下に正しく置くために使う。
    let grabOffset: CGSize
    let cardWidth: CGFloat
    let columns: [Status: CGRect]
    /// 列ごとの並び順。ドラッグ中のカードとその子は除いてある。
    let order: [Status: [(id: UUID, frame: CGRect, canBeParent: Bool)]]

    enum Drop: Equatable {
        case subtask(UUID)
        case insert(Status, Int)
    }

    /// この座標に落としたらどうなるか。
    func drop(at point: CGPoint) -> Drop? {
        guard let status = column(at: point) else { return nil }
        let rows = order[status] ?? []

        // カードの下半分＝サブタスク化
        for row in rows where row.canBeParent {
            let lower = CGRect(x: row.frame.minX, y: row.frame.midY,
                               width: row.frame.width, height: row.frame.height / 2)
            if lower.contains(point) { return .subtask(row.id) }
        }

        // それ以外＝並べ替え。中心より上にいる最初のカードの手前に入る
        let index = rows.firstIndex { point.y < $0.frame.midY } ?? rows.count
        return .insert(status, index)
    }

    /// 列の外で離しても、横方向に最も近い列へ寄せる。
    private func column(at point: CGPoint) -> Status? {
        if let hit = columns.first(where: { $0.value.contains(point) })?.key { return hit }
        let near = columns.filter { point.y >= $0.value.minY - 60 && point.y <= $0.value.maxY + 60 }
        return near.min { abs($0.value.midX - point.x) < abs($1.value.midX - point.x) }?.key
    }
}
