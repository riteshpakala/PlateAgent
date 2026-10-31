import Foundation

/// Where each box sits before anything is measured: the lanes in rows (a lane `beside` the one before shares its
/// row), each lane's boxes in a grid of columns, and each box under another split across that box's width. Its
/// widths are what the measure pass sizes the boxes' text at.
struct PlateGrid: Sendable {
    struct LaneSpan: Sendable {
        let row: Int
        let x: Double
        let w: Double
        /// The left of two lanes side by side says its name at its left foot; every other lane at its right.
        let labelRight: Bool
    }

    struct Cell: Sendable {
        let lane: Int
        /// The grid row within its lane; a box under another shares its parent's.
        let row: Int
        let x: Double
        let width: Double
        /// The box this one is drawn under.
        let parent: String?
    }

    /// Lane indices, a row at a time.
    let rows: [[Int]]
    let lanes: [LaneSpan]
    let cells: [String: Cell]

    var widths: [String: Double] { cells.mapValues(\.width) }

    static func make(_ spec: PlateSpec) -> PlateGrid {
        var rows: [[Int]] = []
        for (i, lane) in spec.lanes.enumerated() {
            if lane.beside == true, let last = rows.last, last.count == 1 { rows[rows.count - 1].append(i) } else { rows.append([i]) }
        }
        var spans = Array(repeating: LaneSpan(row: 0, x: 0, w: 0, labelRight: true), count: spec.lanes.count)
        for (r, row) in rows.enumerated() {
            let w = row.count == 1 ? PlateGeometry.laneW : (PlateGeometry.laneW - PlateGeometry.pairGap) / 2
            for (k, lane) in row.enumerated() {
                spans[lane] = LaneSpan(row: r, x: PlateGeometry.laneX + Double(k) * (w + PlateGeometry.pairGap), w: w,
                                       labelRight: !(row.count == 2 && k == 0))
            }
        }
        var cells: [String: Cell] = [:]
        let ids = Set(spec.nodes.map(\.id))
        for (index, lane) in spec.lanes.enumerated() {
            let span = spans[index]
            let inLane = spec.nodes.filter { $0.lane == lane.id }
            let isChild: (PlateNode) -> Bool = { node in
                guard let under = node.under, ids.contains(under), under != node.id else { return false }
                return inLane.contains { $0.id == under && $0.under == nil }
            }
            let grid = inLane.filter { !isChild($0) }
            let most = span.w > 1000 ? 4 : 2
            let columns = min(max(lane.columns ?? grid.count, 1), most)
            // Row-major, a column hint claiming its column in the first row from the current one where it is free.
            var taken: [[Bool]] = []
            var row = 0
            var placed: [(node: PlateNode, row: Int, column: Int, span: Int)] = []
            func free(_ r: Int, _ c: Int, _ n: Int) -> Bool {
                guard c + n <= columns else { return false }
                if r >= taken.count { return true }
                return (c..<(c + n)).allSatisfy { !taken[r][$0] }
            }
            for node in grid {
                let n = min(max(node.span ?? 1, 1), columns)
                var r = row, c = 0
                if let want = node.column, want >= 1 {
                    c = min(want - 1, columns - n)
                    while !free(r, c, n) { r += 1 }
                } else {
                    search: while true {
                        for candidate in 0...(columns - n) where free(r, candidate, n) { c = candidate; break search }
                        r += 1
                    }
                }
                while taken.count <= r { taken.append(Array(repeating: false, count: columns)) }
                for k in c..<(c + n) { taken[r][k] = true }
                while row < taken.count, !taken[row].contains(false) { row += 1 }
                placed.append((node, r, c, n))
            }
            // A column of agents and externals only is narrower, as flow's MLX is: the services get the width.
            var weights = Array(repeating: 0.0, count: columns)
            for item in placed where item.span == 1 {
                weights[item.column] = max(weights[item.column], (item.node.kind ?? .service) == .service ? 1 : 0.55)
            }
            weights = weights.map { $0 == 0 ? 1 : $0 }
            // A gap a labelled arrow crosses between two boxes side by side is as wide as its label needs.
            var gaps = Array(repeating: PlateGeometry.columnGap, count: max(columns - 1, 0))
            for edge in spec.edges {
                guard let label = edge.label, let a = placed.first(where: { $0.node.id == edge.from }),
                      let b = placed.first(where: { $0.node.id == edge.to }), a.row == b.row else { continue }
                let (left, right) = a.column < b.column ? (a, b) : (b, a)
                guard left.column + left.span == right.column, left.column + left.span - 1 < gaps.count else { continue }
                let need = min(PlateRouter.wireSize(label).w + 28, 170)
                gaps[left.column + left.span - 1] = max(gaps[left.column + left.span - 1], need)
            }
            let inner = span.w - 2 * PlateGeometry.laneSide
            let unit = min((inner - gaps.reduce(0, +)) / weights.reduce(0, +), PlateGeometry.maxCell)
            var widths = weights.map { $0 * unit }
            // A column whose box has a line that cannot wrap (its code, its name) is given what that line needs,
            // from the columns with room to spare.
            var needs = Array(repeating: 0.0, count: columns)
            for item in placed where item.span == 1 { needs[item.column] = max(needs[item.column], Self.unwrapped(item.node)) }
            let deficit = zip(widths, needs).map { max($1 - $0, 0) }.reduce(0, +)
            let slack = zip(widths, needs).map { max($0 - max($1, PlateGeometry.agentMaxWidth), 0) }
            if deficit > 0, slack.reduce(0, +) >= deficit {
                let share = deficit / slack.reduce(0, +)
                for c in 0..<columns { widths[c] = needs[c] > widths[c] ? needs[c] : widths[c] - slack[c] * share }
            }
            let group = widths.reduce(0, +) + gaps.reduce(0, +)
            var lefts: [Double] = []
            var x = span.x + PlateGeometry.laneSide + (inner - group) / 2
            for c in 0..<columns {
                lefts.append(x)
                x += widths[c] + (c < gaps.count ? gaps[c] : 0)
            }
            for item in placed {
                let last = item.column + item.span - 1
                cells[item.node.id] = Cell(lane: index, row: item.row, x: lefts[item.column], width: lefts[last] + widths[last] - lefts[item.column],
                                           parent: nil)
            }
            // Boxes under a box share its width, side by side; an agent keeps an agent's width, centred.
            for parent in grid {
                guard let home = cells[parent.id] else { continue }
                let children = inLane.filter { isChild($0) && $0.under == parent.id }
                guard !children.isEmpty else { continue }
                let count = Double(children.count)
                var width = (home.width - PlateGeometry.childGap * (count - 1)) / count
                if children.allSatisfy({ ($0.kind ?? .service) == .agent }) { width = min(width, PlateGeometry.agentMaxWidth) }
                let total = width * count + PlateGeometry.childGap * (count - 1)
                for (k, child) in children.enumerated() {
                    cells[child.id] = Cell(lane: index, row: home.row,
                                           x: home.x + (home.width - total) / 2 + Double(k) * (width + PlateGeometry.childGap),
                                           width: width, parent: parent.id)
                }
            }
        }
        return PlateGrid(rows: rows, lanes: spans, cells: cells)
    }

    /// The width a box needs for the lines that do not wrap: its code (Menlo 11.5 px) and its name (Playfair italic
    /// 19 px, about half an em a letter), with the box's padding.
    static func unwrapped(_ node: PlateNode) -> Double {
        let pad = 36.0
        let code = Double(node.code?.count ?? 0) * 11.5 * PlatePalette.monoAdvance
        let name = Double(node.name.count) * 19 * 0.5
        return (node.kind ?? .service) == .service ? max(code, name) + pad : 0
    }
}
