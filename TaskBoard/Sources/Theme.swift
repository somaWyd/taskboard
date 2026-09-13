import SwiftUI

/// マット／リキッドグラスの2択を1か所に閉じ込める。
/// glass は macOS 26 の Liquid Glass（glassEffect）をそのまま使う。
struct SurfaceBackground: ViewModifier {
    let surface: Surface
    var radius: CGFloat = 12
    /// カードなど前面に浮くものは true。列やツールバーの土台は false。
    var elevated = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius) }

    func body(content: Content) -> some View {
        switch surface {
        case .matte:
            content.background(
                shape.fill(elevated ? AnyShapeStyle(.background)
                                    : AnyShapeStyle(Color.primary.opacity(0.045)))
            )
        case .glass:
            content.glassEffect(elevated ? .regular.interactive() : .regular, in: shape)
        }
    }
}

struct HairlineBorder: ViewModifier {
    var radius: CGFloat = 12
    var color: Color = .clear
    var width: CGFloat = 0.5

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(color == .clear ? AnyShapeStyle(.separator)
                                              : AnyShapeStyle(color), lineWidth: width)
        }
    }
}

extension View {
    func panel(_ surface: Surface, radius: CGFloat = 12, elevated: Bool = false) -> some View {
        modifier(SurfaceBackground(surface: surface, radius: radius, elevated: elevated))
    }
    func hairline(_ radius: CGFloat = 12, color: Color = .clear, width: CGFloat = 0.5) -> some View {
        modifier(HairlineBorder(radius: radius, color: color, width: width))
    }
}

/// アプリ全体で使う動きの定数。ばらばらのカーブを持ち込まない。
enum Motion {
    static let lift = Animation.spring(response: 0.26, dampingFraction: 0.72)
    static let settle = Animation.spring(response: 0.34, dampingFraction: 0.78)
    static let quick = Animation.easeOut(duration: 0.16)
}
