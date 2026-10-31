import Foundation

/// Where each lane's boxes go along it, so arrows cross less: a box moves toward the boxes it connects to in other
/// lanes (their mean place), lanes top to bottom and back, and the new order is kept only when it crosses fewer
/// arrows than the order the spec wrote. A lane whose boxes name their own columns keeps them.
///
/// PIN: the spec's order wins a tie. A model often writes a lane in the order its story reads (the front ends left to
/// right as the ask passes through them); a reorder has to buy fewer crossings to undo that.
enum PlateOrder {
    static func ordered(_ spec: PlateSpec) -> PlateSpec {
        let original = crossings(spec)
        guard original > 0 else { return spec }
        let parents = Dictionary(spec.nodes.compactMap { node in node.under.map { (node.id, $0) } }, uniquingKeysWith: { a, _ in a })
        func anchor(_ id: String) -> String { parents[id] ?? id }
        var neighbours: [String: [String]] = [:]
        for edge in spec.edges {
            let a = anchor(edge.from), b = anchor(edge.to)
            guard a != b else { continue }
            neighbours[a, default: []].append(b)
            neighbours[b, default: []].append(a)
        }
        var candidate = spec
        for pass in 0..<4 {
            let lanes = pass % 2 == 0 ? Array(candidate.lanes.indices) : Array(candidate.lanes.indices.reversed())
            for index in lanes {
                let grid = PlateGrid.make(candidate)
                let laneID = candidate.lanes[index].id
                let slots = candidate.nodes.indices.filter { candidate.nodes[$0].lane == laneID && parents[candidate.nodes[$0].id] == nil }
                let boxes = slots.map { candidate.nodes[$0] }
                guard boxes.count > 1, !boxes.contains(where: { $0.column != nil || $0.span != nil }) else { continue }
                func centre(_ id: String) -> Double? { grid.cells[id].map { $0.x + $0.width / 2 } }
                let keyed = boxes.enumerated().map { position, node -> (key: Double, position: Int, node: PlateNode) in
                    let others = (neighbours[node.id] ?? []).filter { candidate.node($0)?.lane != laneID }.compactMap(centre)
                    return (others.isEmpty ? centre(node.id) ?? 0 : others.reduce(0, +) / Double(others.count), position, node)
                }
                let sorted = keyed.sorted { $0.key == $1.key ? $0.position < $1.position : $0.key < $1.key }.map(\.node)
                for (slot, node) in zip(slots, sorted) { candidate.nodes[slot] = node }
            }
        }
        return crossings(candidate) < original ? candidate : spec
    }

    /// How many pairs of arrows cross, drawn straight between the middles of the boxes they join.
    static func crossings(_ spec: PlateSpec) -> Int {
        let grid = PlateGrid.make(spec)
        let laneIndex = Dictionary(spec.lanes.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        func point(_ id: String) -> PlatePoint? {
            guard let cell = grid.cells[id], let node = spec.node(id), let lane = laneIndex[node.lane] else { return nil }
            let row = Double(grid.lanes[lane].row) * 10 + Double(cell.row) * 2 + (cell.parent == nil ? 0 : 1)
            return PlatePoint(x: cell.x + cell.width / 2, y: row * 100)
        }
        let segments = spec.edges.compactMap { edge -> (String, String, PlatePoint, PlatePoint)? in
            guard let a = point(edge.from), let b = point(edge.to) else { return nil }
            return (edge.from, edge.to, a, b)
        }
        var count = 0
        for i in segments.indices {
            for j in segments.indices where j > i {
                let (a, b, p, q) = segments[i], (c, d, r, s) = segments[j]
                guard Set([a, b]).isDisjoint(with: [c, d]) else { continue }
                if intersects(p, q, r, s) { count += 1 }
            }
        }
        return count
    }

    private static func intersects(_ p: PlatePoint, _ q: PlatePoint, _ r: PlatePoint, _ s: PlatePoint) -> Bool {
        func cross(_ o: PlatePoint, _ a: PlatePoint, _ b: PlatePoint) -> Double { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        let d1 = cross(r, s, p), d2 = cross(r, s, q), d3 = cross(p, q, r), d4 = cross(p, q, s)
        return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
    }
}
