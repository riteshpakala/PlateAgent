import Foundation

/// A point on the page, in CSS pixels.
struct PlatePoint: Sendable, Equatable {
    var x: Double
    var y: Double

    func distance(to other: PlatePoint) -> Double { ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot() }
}
