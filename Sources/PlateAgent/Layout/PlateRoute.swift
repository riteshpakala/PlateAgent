import Foundation

/// One arrow as drawn: where it starts, its segments, its stroke, its heads, what it crossed, and where its number
/// and label went.
struct PlateRoute: Sendable {
    enum Direction: Sendable { case up, down, left, right }

    struct Head: Sendable {
        let x: Double
        let y: Double
        let direction: Direction
    }

    enum Segment: Sendable {
        case line(PlatePoint)
        case cubic(PlatePoint, PlatePoint, PlatePoint)

        var end: PlatePoint {
            switch self {
            case .line(let p): return p
            case .cubic(_, _, let p): return p
            }
        }
    }

    /// The arrow's index in the spec's edges.
    let edge: Int
    var start: PlatePoint
    var segments: [Segment]
    var colour: PlateColour
    var dashed: Bool
    var both: Bool
    /// The boxes it passes through, by id: a finding for the model.
    var crossings: [String] = []
    /// Where its number sits, on the path.
    var mark: PlatePoint?
    /// Where its label sits, beside the path.
    var wire: PlateBox?

    var end: PlatePoint { segments.last?.end ?? start }

    var d: String {
        let n = PlateHTML.n
        var path = "M\(n(start.x)),\(n(start.y))"
        for segment in segments {
            switch segment {
            case .line(let p): path += " L\(n(p.x)),\(n(p.y))"
            case .cubic(let a, let b, let p): path += " C\(n(a.x)),\(n(a.y)) \(n(b.x)),\(n(b.y)) \(n(p.x)),\(n(p.y))"
            }
        }
        return path
    }

    /// A head where the arrow ends, pointing the way it arrives, and one where it starts for an arrow both ways.
    var heads: [Head] {
        var heads = [Head(x: end.x, y: end.y, direction: Self.direction(from: arrivingFrom, to: end))]
        if both, let first = segments.first {
            let away: PlatePoint
            switch first {
            case .line(let p): away = p
            case .cubic(let a, _, _): away = a == start ? first.end : a
            }
            heads.append(Head(x: start.x, y: start.y, direction: Self.direction(from: away, to: start)))
        }
        return heads
    }

    /// Points along the path, `per` to a segment: what a crossing is tested on and a mark placed by.
    func samples(per: Int = 24) -> [PlatePoint] {
        var points = [start]
        var from = start
        for segment in segments {
            for k in 1...per {
                let t = Double(k) / Double(per)
                switch segment {
                case .line(let p): points.append(PlatePoint(x: from.x + (p.x - from.x) * t, y: from.y + (p.y - from.y) * t))
                case .cubic(let a, let b, let p): points.append(Self.bezier(from, a, b, p, t))
                }
            }
            from = segment.end
        }
        return points
    }

    /// The point `fraction` of the way along the path, and whether the path runs more up and down than across there.
    func point(at fraction: Double) -> (point: PlatePoint, vertical: Bool) {
        let points = samples()
        var lengths: [Double] = [0]
        for i in 1..<points.count { lengths.append(lengths[i - 1] + points[i].distance(to: points[i - 1])) }
        let target = (lengths.last ?? 0) * fraction
        let i = max(1, lengths.firstIndex { $0 >= target } ?? points.count - 1)
        let a = points[i - 1], b = points[i]
        return (b, abs(b.y - a.y) >= abs(b.x - a.x))
    }

    private var arrivingFrom: PlatePoint {
        guard let last = segments.last else { return start }
        switch last {
        case .line:
            return segments.count > 1 ? segments[segments.count - 2].end : start
        case .cubic(let a, let b, let p):
            return b != p ? b : (a != p ? a : (segments.count > 1 ? segments[segments.count - 2].end : start))
        }
    }

    static func direction(from a: PlatePoint, to b: PlatePoint) -> Direction {
        let dx = b.x - a.x, dy = b.y - a.y
        return abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
    }

    static func bezier(_ p0: PlatePoint, _ p1: PlatePoint, _ p2: PlatePoint, _ p3: PlatePoint, _ t: Double) -> PlatePoint {
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return PlatePoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x, y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
    }
}
