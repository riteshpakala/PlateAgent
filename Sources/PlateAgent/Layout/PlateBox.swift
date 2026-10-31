import Foundation

/// A rectangle on the page, in CSS pixels.
struct PlateBox: Sendable, Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    var right: Double { x + w }
    var bottom: Double { y + h }
    var midX: Double { x + w / 2 }
    var midY: Double { y + h / 2 }

    /// Grown by `d` on every side (shrunk when negative).
    func inset(_ d: Double) -> PlateBox { PlateBox(x: x - d, y: y - d, w: w + 2 * d, h: h + 2 * d) }

    func contains(_ p: PlatePoint) -> Bool { p.x > x && p.x < right && p.y > y && p.y < bottom }

    /// The area two boxes share; zero when they only touch.
    func overlap(_ other: PlateBox) -> Double {
        let w = min(right, other.right) - max(x, other.x), h = min(bottom, other.bottom) - max(y, other.y)
        return w > 0 && h > 0 ? w * h : 0
    }

    func shifted(dy: Double) -> PlateBox { PlateBox(x: x, y: y + dy, w: w, h: h) }
}
