import CoreGraphics

/// KanbanView.columnRects と同じ計算。配置の前提が変わったら気づけるようにする。
func columnRects(boardWidth: CGFloat, boardHeight: CGFloat, count: Int) -> [CGRect] {
    let pad: CGFloat = 14, gap: CGFloat = 12
    let width = (boardWidth - pad * 2 - gap * CGFloat(count - 1)) / CGFloat(count)
    guard width > 0 else { return [] }
    return (0..<count).map { i in
        CGRect(x: pad + (width + gap) * CGFloat(i), y: pad,
               width: width, height: max(boardHeight - pad * 2, 0))
    }
}
