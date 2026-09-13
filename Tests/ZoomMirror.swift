import Foundation

/// AppSettings.zoom と同じ計算。上限・下限の扱いを検証する。
struct ZoomMirror {
    static let range: ClosedRange<Double> = 11...22
    static let standard: Double = 13
    static func zoom(_ current: Double, by delta: Double) -> Double {
        min(max(current + delta, range.lowerBound), range.upperBound)
    }
}
