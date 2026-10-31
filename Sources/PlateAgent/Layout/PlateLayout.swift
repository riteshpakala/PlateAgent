import Foundation

/// Where everything on a plate goes, from the spec, the grid and what WebKit measured: deterministic, so the same
/// spec draws the same plate, and nothing in it is the model's to place.
///
/// The lanes stack top to bottom in the spec's order (two side by side when one says `beside`); in a lane, each
/// grid row is as tall as its tallest box, boxes under a box hang below it, and the lane's foot holds its name.
/// Then the arrows are routed, a lane grows when an arrow runs under its last row, the numbers and labels are
/// placed clear of everything, and the legend and the card close it.
struct PlateLayout: Sendable {
    struct Lane: Sendable {
        let lane: PlateLane
        var box: PlateBox
        let labelRight: Bool

        /// Where its name sits, for labels to keep clear of: small capitals spaced .22 em, about 9.7 px a letter.
        var labelBox: PlateBox {
            let w = Double(lane.name.count) * 9.7
            return PlateBox(x: labelRight ? box.right - 18 - w : box.x + 18, y: box.bottom - 30, w: w, h: 15)
        }
    }

    struct Node: Sendable {
        let node: PlateNode
        var box: PlateBox
        let kind: PlateNodeKind
        let colour: PlateColour
    }

    var lanes: [Lane]
    var nodes: [Node]
    /// Each lane's note, where it sits.
    var notes: [(lane: String, box: PlateBox, text: String)] = []
    var routes: [PlateRoute]
    var legend: PlateBox?
    var card: PlateBox
    /// The page's height before the header script brings the card to the header's rhythm.
    var height: Double
    /// What the layout could not avoid: arrows through boxes.
    var findings: [PlateFinding]

    static func make(_ spec: PlateSpec, grid: PlateGrid, measures: PlateMeasures) -> PlateLayout {
        // Each lane laid out on its own, from its top.
        var local: [String: PlateBox] = [:]
        var laneHeights = Array(repeating: 0.0, count: spec.lanes.count)
        var laneNotes: [Int: (box: PlateBox, text: String)] = [:]
        for (index, _) in spec.lanes.enumerated() {
            let cells = grid.cells.filter { $0.value.lane == index }
            let gridIDs = cells.filter { $0.value.parent == nil }
            var y = PlateGeometry.laneTop, bottom = y
            let rows = Set(gridIDs.values.map(\.row)).sorted()
            for row in rows {
                let inRow = spec.nodes.filter { gridIDs[$0.id]?.row == row }
                let rowH = inRow.map { height(of: $0, measures) }.max() ?? PlateGeometry.minNode
                var rowBottom = y + rowH
                for node in inRow {
                    guard let cell = cells[node.id] else { continue }
                    let own = height(of: node, measures)
                    let box: PlateBox
                    switch node.kind ?? .service {
                    case .service: box = PlateBox(x: cell.x, y: y, w: cell.width, h: rowH)
                    case .agent: box = PlateBox(x: cell.x, y: y + (rowH - own) / 2, w: cell.width, h: own)
                    case .external:
                        box = rowH - 16 >= own ? PlateBox(x: cell.x, y: y + 8, w: cell.width, h: rowH - 16)
                            : PlateBox(x: cell.x, y: y + (rowH - own) / 2, w: cell.width, h: own)
                    }
                    local[node.id] = box
                    let children = spec.nodes.filter { cells[$0.id]?.parent == node.id }
                    guard !children.isEmpty else { continue }
                    let top = box.bottom + PlateGeometry.underGap
                    let childH = children.map { height(of: $0, measures) }.max() ?? PlateGeometry.agentHeight
                    for child in children {
                        guard let childCell = cells[child.id] else { continue }
                        let own = height(of: child, measures)
                        local[child.id] = PlateBox(x: childCell.x, y: top + (childH - own) / 2, w: childCell.width, h: own)
                    }
                    rowBottom = max(rowBottom, top + childH)
                }
                bottom = rowBottom
                y = rowBottom + PlateGeometry.rowGap
            }
            var foot = rows.isEmpty ? PlateGeometry.laneTop + 40 : bottom
            // The lane's note: beside its boxes when the lane has room to their right, else under them.
            if let note = spec.lanes[index].note {
                let span = grid.lanes[index]
                let right = local.filter { cells[$0.key] != nil }.map { $0.value.right }.max() ?? span.x
                let room = span.x + span.w - PlateGeometry.laneSide - (right + PlateGeometry.columnGap)
                let beside = room >= 260
                let width = beside ? room : span.w - 2 * PlateGeometry.laneSide
                let lines = max(1, ceil(Double(note.count) * 7.3 / max(width, 100)))
                let box = beside ? PlateBox(x: right + PlateGeometry.columnGap, y: PlateGeometry.laneTop + 2, w: width, h: lines * 20)
                    : PlateBox(x: span.x + PlateGeometry.laneSide, y: foot + 10, w: width, h: lines * 20)
                laneNotes[index] = (box, note)
                foot = max(foot, box.bottom)
            }
            laneHeights[index] = foot + PlateGeometry.laneFoot
        }

        // The lanes placed, the arrows routed; a lane an arrow runs under grows to hold it, and the two go again.
        var extra = Array(repeating: 0.0, count: spec.lanes.count)
        var layout = PlateLayout(lanes: [], nodes: [], routes: [], legend: nil, card: PlateBox(x: 0, y: 0, w: 0, h: 0), height: 0, findings: [])
        for _ in 0..<4 {
            var laneBoxes = Array(repeating: PlateBox(x: 0, y: 0, w: 0, h: 0), count: spec.lanes.count)
            var y = PlateGeometry.firstLane
            for row in grid.rows {
                let h = row.map { laneHeights[$0] + extra[$0] }.max() ?? 0
                for index in row {
                    let span = grid.lanes[index]
                    laneBoxes[index] = PlateBox(x: span.x, y: y, w: span.w, h: h)
                }
                y += h + PlateGeometry.laneGap
            }
            let laneIndex = Dictionary(spec.lanes.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
            var nodes: [Node] = []
            for node in spec.nodes {
                guard let box = local[node.id], let index = laneIndex[node.lane] else { continue }
                let lane = spec.lanes[index]
                let colour = node.colour ?? (lane.colour == .dial ? .line : lane.colour)
                nodes.append(Node(node: node, box: box.shifted(dy: laneBoxes[index].y), kind: node.kind ?? .service, colour: colour))
            }
            let boxes = Dictionary(nodes.map { ($0.node.id, $0.box) }, uniquingKeysWith: { a, _ in a })
            let laneOf = Dictionary(nodes.compactMap { node in laneIndex[node.node.lane].map { (node.node.id, laneBoxes[$0]) } }, uniquingKeysWith: { a, _ in a })
            let colours = Dictionary(nodes.map { ($0.node.id, $0.colour) }, uniquingKeysWith: { a, _ in a })
            let routes = PlateRouter.routes(spec, boxes: boxes, lanes: laneOf, colours: colours)
            layout.lanes = spec.lanes.enumerated().map { Lane(lane: $1, box: laneBoxes[$0], labelRight: grid.lanes[$0].labelRight) }
            layout.notes = laneNotes.sorted { $0.key < $1.key }.map { index, note in
                (spec.lanes[index].id, note.box.shifted(dy: laneBoxes[index].y), note.text)
            }
            layout.nodes = nodes
            layout.routes = routes
            // An arrow that runs under a lane's last row needs the lane's foot below it.
            var grew = false
            for route in routes {
                let edge = spec.edges[route.edge]
                guard let index = laneIndex[spec.node(edge.from)?.lane ?? ""], laneIndex[spec.node(edge.to)?.lane ?? ""] == index else { continue }
                let lowest = route.samples(per: 4).map(\.y).max() ?? 0
                let need = lowest + 36 - laneBoxes[index].bottom
                if need > 0.5, lowest > (boxes[edge.from]?.bottom ?? 0) + 4 { extra[index] += need; grew = true }
            }
            if !grew { break }
        }

        let obstacles = layout.nodes.map { $0.box.inset(2) } + layout.lanes.map(\.labelBox) + layout.notes.map(\.box)
        PlateRouter.label(&layout.routes, spec, obstacles: obstacles)

        let lanesBottom = layout.lanes.map(\.box.bottom).max() ?? PlateGeometry.firstLane
        let legendText = spec.legendText
        if !legendText.isEmpty {
            layout.legend = PlateBox(x: PlateGeometry.legendX, y: lanesBottom + PlateGeometry.legendGap, w: PlateGeometry.legendW,
                                     h: max(measures.legend, 21))
        }
        let foot = (layout.legend?.bottom ?? lanesBottom) + PlateGeometry.cardFoot
        layout.card = PlateBox(x: PlateGeometry.cardX, y: PlateGeometry.cardY, w: PlateGeometry.cardW, h: foot - PlateGeometry.cardY)
        layout.height = layout.card.bottom + PlateGeometry.pageFoot

        let names = Dictionary(spec.nodes.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        layout.findings = layout.routes.filter { !$0.crossings.isEmpty }.map { route in
            let edge = spec.edges[route.edge]
            let crossed = route.crossings.map { names[$0] ?? $0 }.joined(separator: ", ")
            return PlateFinding(.crossing, "edge:\(route.edge + 1)",
                                "arrow \(route.edge + 1) (\(names[edge.from] ?? edge.from) → \(names[edge.to] ?? edge.to)) is drawn through \(crossed): "
                                    + "put the two ends in neighbouring columns or in lanes one above the other, or move \(crossed) to another column.")
        }
        return layout
    }

    /// The spec with a box an arrow is drawn through moved along its lane, when that clears it: the box swaps places
    /// with another of its lane, and the swap is kept when fewer arrows cross a box. The frame's lanes (dial) and a box
    /// that names its column stay. Laid out with reckoned heights, before WebKit measures.
    static func cleared(_ spec: PlateSpec) -> PlateSpec {
        func crossings(_ spec: PlateSpec) -> (count: Int, crossed: Set<String>) {
            let grid = PlateGrid.make(spec)
            let routes = make(spec, grid: grid, measures: .estimated(spec, grid: grid)).routes.filter { !$0.crossings.isEmpty }
            return (routes.count, Set(routes.flatMap(\.crossings)))
        }
        var best = spec
        var score = crossings(spec)
        for _ in 0..<3 where score.count > 0 {
            var improved = false
            for id in score.crossed.sorted() {
                guard let i = best.nodes.firstIndex(where: { $0.id == id }), best.nodes[i].under == nil, best.nodes[i].column == nil,
                      best.lanes.first(where: { $0.id == best.nodes[i].lane })?.colour != .dial else { continue }
                let lane = best.nodes[i].lane
                for j in best.nodes.indices where j != i && best.nodes[j].lane == lane && best.nodes[j].under == nil && best.nodes[j].column == nil {
                    var trial = best
                    trial.nodes.swapAt(i, j)
                    let next = crossings(trial)
                    if next.count < score.count { best = trial; score = next; improved = true; break }
                }
                if improved { break }
            }
            if !improved { break }
        }
        return best
    }

    /// The spec without the arrows the walk does not need that no route can draw clear of the boxes: an unnumbered
    /// arrow is the reader's aid, and one drawn through a box hurts more than it helps. Laid out with reckoned
    /// heights, before WebKit measures; a numbered arrow always stays, and a crossing it makes is a finding.
    static func pruned(_ spec: PlateSpec) -> PlateSpec {
        var spec = spec
        for _ in 0..<3 {
            let grid = PlateGrid.make(spec)
            let layout = make(spec, grid: grid, measures: .estimated(spec, grid: grid))
            let crossing = Set(layout.routes.filter { !$0.crossings.isEmpty && spec.edges[$0.edge].number == nil }.map(\.edge))
            guard !crossing.isEmpty else { break }
            spec.edges = spec.edges.enumerated().filter { !crossing.contains($0.offset) }.map(\.element)
        }
        return spec
    }

    /// A box's height: a service is what it says plus its foot; an agent is an agent's height; an external is
    /// what it says, padded.
    static func height(of node: PlateNode, _ measures: PlateMeasures) -> Double {
        let measured = measures.heights[node.id] ?? 0
        switch node.kind ?? .service {
        case .service: return max(PlateGeometry.minNode, measured + PlateGeometry.nodeFoot)
        case .agent: return PlateGeometry.agentHeight
        case .external: return max(PlateGeometry.minExternal, measured + PlateGeometry.externalPad)
        }
    }
}
