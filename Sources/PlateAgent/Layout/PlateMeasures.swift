import Foundation

/// What WebKit measured before the layout: each box's content at its width, and the legend's height. The layout's
/// one input that is not the spec.
public struct PlateMeasures: Sendable, Equatable {
    /// Box id → the height of what it says, at the width the grid gives it.
    public var heights: [String: Double]
    public var legend: Double

    public init(heights: [String: Double], legend: Double) {
        self.heights = heights; self.legend = legend
    }

    /// A reckoning without WebKit, for a layout a test lays out: Playfair at 14.5 px is about 7 px a character.
    static func estimated(_ spec: PlateSpec, grid: PlateGrid) -> PlateMeasures {
        var heights: [String: Double] = [:]
        for node in spec.nodes {
            let width = grid.cells[node.id]?.width ?? 300
            let lines = node.duty.map { max(1, ceil(Double($0.count) * 7.0 / max(width - 34, 60))) } ?? 0
            heights[node.id] = 10 + 22 + lines * 19 + (node.code == nil ? 0 : 19)
        }
        let legend = spec.legend.map { max(1, ceil(Double($0.count) * 7.4 / PlateGeometry.legendW)) * 21 } ?? 0
        return PlateMeasures(heights: heights, legend: legend)
    }
}
