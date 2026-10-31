import Foundation

/// How each arrow is drawn: the shapes the plates use, tried in order, the first that crosses no box kept.
///
/// - direct: out of the side that faces the other box and into the one that faces back, straight when the two
///   line up and a curve when they do not;
/// - an elbow: across then up or down (flow's run to MLX), or down then across;
/// - round a gutter: out of a box's side, along the outside of the lanes, into the other's side (flow's arrow 8);
/// - under or over a row: down out of one box, along under everything between, up into the other (flow's
///   `route(.model)`).
///
/// PIN: a route that crosses a box whatever its shape is still drawn, the shape that crossed fewest, and the
/// crossing is a finding: what to change is the model's (two boxes in neighbouring columns, a lane between them),
/// not a guess here.
enum PlateRouter {
    enum Side: Sendable { case top, bottom, left, right }
    enum Shape: Sendable { case direct, elbowAcross, elbowDown, gutterLeft, gutterRight, under, over, detour }
    private enum Relation { case down, up, right, left }

    /// One arrow's plan: its shape, the sides it leaves and enters, and where along each.
    struct Plan: Sendable {
        let shape: Shape
        let fromSide: Side
        let toSide: Side
        var from: Double
        var to: Double
        /// For a detour: the x it runs up or down at, beside the box it goes round, and that box.
        var via: Double? = nil
        var around: PlateBox? = nil
    }

    struct Ends: Sendable {
        let from: String
        let to: String
        let a: PlateBox
        let b: PlateBox
        /// The lanes the two boxes sit in, for the gutters.
        let laneA: PlateBox
        let laneB: PlateBox
    }

    // MARK: Routing

    static func routes(_ spec: PlateSpec, boxes: [String: PlateBox], lanes: [String: PlateBox], colours: [String: PlateColour]) -> [PlateRoute] {
        var routes: [PlateRoute] = []
        var plans: [Plan] = []
        var ends: [Ends] = []
        for (i, edge) in spec.edges.enumerated() {
            guard let a = boxes[edge.from], let b = boxes[edge.to], let laneA = lanes[edge.from], let laneB = lanes[edge.to] else { continue }
            let pair = Ends(from: edge.from, to: edge.to, a: a, b: b, laneA: laneA, laneB: laneB)
            let style = edge.style ?? .solid
            let colour = edge.colour ?? (style == .dashedGold ? .gold : style == .dashedGrey ? .dial : colours[edge.from] ?? .line)
            var best: (route: PlateRoute, plan: Plan)?
            for plan in candidates(pair) {
                guard var route = build(plan, pair, boxes: boxes, edge: i) else { continue }
                route.colour = colour; route.dashed = style != .solid; route.both = edge.both ?? false
                route.crossings = crossings(route, pair, boxes: boxes)
                if best == nil || route.crossings.count < best!.route.crossings.count { best = (route, plan) }
                if route.crossings.isEmpty { break }
            }
            // Still through a box: go round it, beside whichever of its sides is nearer.
            if var found = best, let first = found.route.crossings.first, let box = boxes[first] {
                for plan in detours(pair, around: box) {
                    guard var route = build(plan, pair, boxes: boxes, edge: i) else { continue }
                    route.colour = colour; route.dashed = style != .solid; route.both = edge.both ?? false
                    route.crossings = crossings(route, pair, boxes: boxes)
                    if route.crossings.count < found.route.crossings.count { found = (route, plan) }
                    if route.crossings.isEmpty { break }
                }
                best = found
            }
            guard let best else { continue }
            routes.append(best.route); plans.append(best.plan); ends.append(pair)
        }
        spread(&routes, plans: &plans, ends: ends, boxes: boxes)
        return routes
    }

    /// Where several arrows leave or enter one side of a box, they are spread along it in the order of where they
    /// go, unless where they would each go on their own is already apart.
    private static func spread(_ routes: inout [PlateRoute], plans: inout [Plan], ends: [Ends], boxes: [String: PlateBox]) {
        struct Use { let route: Int; let start: Bool; let at: Double; let far: Double }
        var groups: [String: [Use]] = [:]
        func key(_ id: String, _ side: Side) -> String { "\(id)|\(side)" }
        for (i, plan) in plans.enumerated() {
            let pair = ends[i]
            groups[key(pair.from, plan.fromSide), default: []].append(Use(route: i, start: true, at: plan.from, far: plan.to))
            groups[key(pair.to, plan.toSide), default: []].append(Use(route: i, start: false, at: plan.to, far: plan.from))
        }
        var changed: Set<Int> = []
        for (groupKey, uses) in groups where uses.count > 1 {
            let sorted = uses.sorted { $0.at == $1.at ? $0.far < $1.far : $0.at < $1.at }
            let apart = zip(sorted, sorted.dropFirst()).allSatisfy { $1.at - $0.at >= 22 }
            guard !apart else { continue }
            let parts = groupKey.split(separator: "|")
            guard let box = boxes[String(parts[0])] else { continue }
            let horizontal = parts[1] == "top" || parts[1] == "bottom"
            let origin = horizontal ? box.x : box.y, length = horizontal ? box.w : box.h
            let byFar = uses.sorted { $0.far < $1.far }
            for (k, use) in byFar.enumerated() {
                let at = origin + length * Double(k + 1) / Double(byFar.count + 1)
                if use.start { plans[use.route].from = at } else { plans[use.route].to = at }
                changed.insert(use.route)
            }
        }
        for i in changed {
            guard var route = build(plans[i], ends[i], boxes: boxes, edge: routes[i].edge) else { continue }
            route.colour = routes[i].colour; route.dashed = routes[i].dashed; route.both = routes[i].both
            route.crossings = crossings(route, ends[i], boxes: boxes)
            routes[i] = route
        }
    }

    private static func relation(_ a: PlateBox, _ b: PlateBox) -> Relation {
        if b.y >= a.bottom + 6 { return .down }
        if b.bottom <= a.y - 6 { return .up }
        if b.x >= a.right - 1 { return .right }
        if b.right <= a.x + 1 { return .left }
        return b.midY >= a.midY ? .down : .up
    }

    /// The shapes worth trying for two boxes, in the order the plates prefer them.
    private static func candidates(_ e: Ends) -> [Plan] {
        let a = e.a, b = e.b
        func along(_ target: Double, _ lo: Double, _ length: Double) -> Double {
            min(max(target, lo + length * 0.2), lo + length * 0.8)
        }
        let toward: Side = b.midX >= a.midX ? .right : .left
        let facing: Side = a.midX <= b.midX ? .left : .right
        switch relation(a, b) {
        case .down, .up:
            let down = relation(a, b) == .down
            let lo = max(a.x, b.x), hi = min(a.right, b.right)
            let direct = hi - lo >= 30
                ? Plan(shape: .direct, fromSide: down ? .bottom : .top, toSide: down ? .top : .bottom, from: (lo + hi) / 2, to: (lo + hi) / 2)
                : Plan(shape: .direct, fromSide: down ? .bottom : .top, toSide: down ? .top : .bottom,
                       from: along(b.midX, a.x, a.w), to: along(a.midX, b.x, b.w))
            // Then the same straight run nearer either side, which clears a box sitting between the two.
            let shifted = [0.15, 0.85, 0.32, 0.68].map { f in
                Plan(shape: .direct, fromSide: down ? .bottom : .top, toSide: down ? .top : .bottom, from: a.x + a.w * f, to: b.x + b.w * f)
            }
            return [direct] + shifted + [
                    Plan(shape: .elbowAcross, fromSide: toward, toSide: down ? .top : .bottom, from: a.midY, to: b.midX),
                    Plan(shape: .elbowDown, fromSide: down ? .bottom : .top, toSide: facing, from: along(b.midX, a.x, a.w), to: b.midY),
                    Plan(shape: .gutterLeft, fromSide: .left, toSide: .left, from: a.midY, to: b.midY),
                    Plan(shape: .gutterRight, fromSide: .right, toSide: .right, from: a.midY, to: b.midY)]
        case .right, .left:
            let right = relation(a, b) == .right
            let lo = max(a.y, b.y), hi = min(a.bottom, b.bottom)
            let direct = hi - lo >= 20
                ? Plan(shape: .direct, fromSide: right ? .right : .left, toSide: right ? .left : .right, from: (lo + hi) / 2, to: (lo + hi) / 2)
                : Plan(shape: .direct, fromSide: right ? .right : .left, toSide: right ? .left : .right,
                       from: along(b.midY, a.y, a.h), to: along(a.midY, b.y, b.h))
            let shifted = [0.3, 0.7].map { f in
                Plan(shape: .direct, fromSide: right ? .right : .left, toSide: right ? .left : .right, from: a.y + a.h * f, to: b.y + b.h * f)
            }
            return [direct] + shifted + [
                    Plan(shape: .under, fromSide: .bottom, toSide: .bottom, from: along(b.midX, a.x, a.w), to: along(a.midX, b.x, b.w)),
                    Plan(shape: .over, fromSide: .top, toSide: .top, from: along(b.midX, a.x, a.w), to: along(a.midX, b.x, b.w))]
        }
    }

    /// Round `box`, up or down beside its nearer side first, then its other: for two boxes one above the other
    /// with a third between them.
    private static func detours(_ e: Ends, around box: PlateBox) -> [Plan] {
        let a = e.a, b = e.b
        guard relation(a, b) == .down || relation(a, b) == .up else { return [] }
        let down = relation(a, b) == .down
        let sides = [box.x - 20, box.right + 20].sorted { abs($0 - a.midX) < abs($1 - a.midX) }
        return sides.map { x in
            Plan(shape: .detour, fromSide: down ? .bottom : .top, toSide: down ? .top : .bottom,
                 from: min(max(x, a.x + 14), a.right - 14), to: min(max(x, b.x + 14), b.right - 14), via: x, around: box)
        }
    }

    private static func point(_ box: PlateBox, _ side: Side, _ at: Double, outset: Double = 0) -> PlatePoint {
        switch side {
        case .top: return PlatePoint(x: at, y: box.y - outset)
        case .bottom: return PlatePoint(x: at, y: box.bottom + outset)
        case .left: return PlatePoint(x: box.x - outset, y: at)
        case .right: return PlatePoint(x: box.right + outset, y: at)
        }
    }

    /// The route a plan draws; nil when the shape does not fit the two boxes.
    static func build(_ plan: Plan, _ e: Ends, boxes: [String: PlateBox], edge: Int) -> PlateRoute? {
        let s = point(e.a, plan.fromSide, plan.from)
        let t = point(e.b, plan.toSide, plan.to, outset: 2)
        var segments: [PlateRoute.Segment]
        switch plan.shape {
        case .direct:
            let vertical = plan.fromSide == .top || plan.fromSide == .bottom
            if vertical {
                if abs(s.x - t.x) < 3 { segments = [.line(PlatePoint(x: s.x, y: t.y))] } else {
                    let ym = (s.y + t.y) / 2
                    segments = [.cubic(PlatePoint(x: s.x, y: ym), PlatePoint(x: t.x, y: ym), t)]
                }
            } else {
                if abs(s.y - t.y) < 3 { segments = [.line(PlatePoint(x: t.x, y: s.y))] } else {
                    let xm = (s.x + t.x) / 2
                    segments = [.cubic(PlatePoint(x: xm, y: s.y), PlatePoint(x: xm, y: t.y), t)]
                }
            }
        case .elbowAcross:
            // Across first, then up or down into the box: only when the turn is clear of the box it left.
            if plan.fromSide == .right, t.x < e.a.right + 14 { return nil }
            if plan.fromSide == .left, t.x > e.a.x - 14 { return nil }
            segments = [.line(PlatePoint(x: t.x, y: s.y)), .line(t)]
        case .elbowDown:
            if s.x > e.b.x - 14 && s.x < e.b.right + 14 { return nil }
            if plan.fromSide == .bottom, t.y < e.a.bottom + 14 { return nil }
            if plan.fromSide == .top, t.y > e.a.y - 14 { return nil }
            let corner = PlatePoint(x: s.x, y: t.y)
            segments = [.line(corner), .line(t)]
        case .gutterLeft, .gutterRight:
            let g = plan.shape == .gutterLeft ? min(e.laneA.x, e.laneB.x) - PlateGeometry.gutter : max(e.laneA.right, e.laneB.right) + PlateGeometry.gutter
            segments = [.cubic(PlatePoint(x: g, y: s.y), PlatePoint(x: g, y: t.y), t)]
        case .detour:
            guard let x = plan.via, let box = plan.around else { return nil }
            let down = plan.fromSide == .bottom
            let enter = down ? box.y - 12 : box.bottom + 12, leave = down ? box.bottom + 12 : box.y - 12
            let m1 = (s.y + enter) / 2, m2 = (leave + t.y) / 2
            segments = [.cubic(PlatePoint(x: s.x, y: m1), PlatePoint(x: x, y: m1), PlatePoint(x: x, y: enter)),
                        .line(PlatePoint(x: x, y: leave)),
                        .cubic(PlatePoint(x: x, y: m2), PlatePoint(x: t.x, y: m2), t)]
        case .under, .over:
            let below = plan.shape == .under
            let lo = min(s.x, t.x) - 6, hi = max(s.x, t.x) + 6
            var run = below ? max(e.a.bottom, e.b.bottom) + PlateGeometry.uRun : min(e.a.y, e.b.y) - PlateGeometry.uRun
            for _ in 0..<12 {
                let blocking = boxes.values.filter { $0.right > lo && $0.x < hi && run > $0.y - 12 && run < $0.bottom + 12 }
                guard !blocking.isEmpty else { break }
                run = below ? blocking.map(\.bottom).max()! + PlateGeometry.uRun : blocking.map(\.y).min()! - PlateGeometry.uRun
            }
            segments = [.line(PlatePoint(x: s.x, y: run)), .line(PlatePoint(x: t.x, y: run)), .line(t)]
        }
        return PlateRoute(edge: edge, start: s, segments: segments, colour: .line, dashed: false, both: false)
    }

    /// The boxes a route passes through, other than its own two ends.
    static func crossings(_ route: PlateRoute, _ e: Ends, boxes: [String: PlateBox]) -> [String] {
        let points = route.samples()
        return boxes.filter { id, box in
            id != e.from && id != e.to && points.contains { box.inset(3).contains($0) }
        }.map(\.key).sorted()
    }

    // MARK: Numbers and labels

    /// A label's box: Menlo at 12 px is 0.6 em an advance, with the pill's padding.
    static func wireSize(_ text: String) -> (w: Double, h: Double) {
        (Double(text.count) * 12 * PlatePalette.monoAdvance + 10, PlateGeometry.wireHeight)
    }

    /// Places each arrow's number on its path and its label beside it, clear of every box, lane name and label
    /// placed before it, and inside the page. What cannot be placed clear goes where the plates put it first, and
    /// the measure pass says what it covers.
    static func label(_ routes: inout [PlateRoute], _ spec: PlateSpec, obstacles: [PlateBox]) {
        var taken = obstacles
        let page = PlateBox(x: 4, y: 0, w: PlatePalette.width - 8, h: 100_000)
        func clear(_ box: PlateBox) -> Bool {
            box.x >= page.x && box.right <= page.right && !taken.contains { $0.overlap(box) > 0.5 }
        }
        for i in routes.indices {
            let edge = spec.edges[routes[i].edge]
            guard edge.number != nil || edge.label != nil else { continue }
            var at = routes[i].point(at: 0.5)
            if edge.number != nil {
                for fraction in [0.5, 0.42, 0.58, 0.34, 0.66, 0.26, 0.74] {
                    let candidate = routes[i].point(at: fraction)
                    let disc = PlateBox(x: candidate.point.x - 12, y: candidate.point.y - 12, w: 24, h: 24)
                    if clear(disc) { at = candidate; break }
                }
                routes[i].mark = at.point
                taken.append(PlateBox(x: at.point.x - 12, y: at.point.y - 12, w: 24, h: 24))
            }
            guard let text = edge.label else { continue }
            let (w, h) = wireSize(text)
            let p = at.point, gap = edge.number == nil ? 10.0 : 17.0
            let options: [PlatePoint] = at.vertical
                ? [PlatePoint(x: p.x + gap, y: p.y - h / 2), PlatePoint(x: p.x - gap - w, y: p.y - h / 2),
                   PlatePoint(x: p.x + gap, y: p.y + 8), PlatePoint(x: p.x + gap, y: p.y - h - 8),
                   PlatePoint(x: p.x - gap - w, y: p.y + 8), PlatePoint(x: p.x - gap - w, y: p.y - h - 8)]
                : [PlatePoint(x: p.x - w / 2, y: p.y + gap - 2), PlatePoint(x: p.x - w / 2, y: p.y - gap - h + 2),
                   PlatePoint(x: p.x + gap, y: p.y + 6), PlatePoint(x: p.x + gap, y: p.y - h - 6),
                   PlatePoint(x: p.x - gap - w, y: p.y + 6), PlatePoint(x: p.x - gap - w, y: p.y - h - 6)]
            // Past the boxes around a short arrow: above and below them, centred on the arrow.
            let further = [30.0, 46.0, 62.0].flatMap { d in [PlatePoint(x: p.x - w / 2, y: p.y + d), PlatePoint(x: p.x - w / 2, y: p.y - d - h)] }
            let boxes = (options + further).map { PlateBox(x: $0.x, y: $0.y, w: w, h: h) }
            let chosen = boxes.first(where: clear) ?? boxes[0]
            routes[i].wire = chosen
            taken.append(chosen)
        }
    }
}
