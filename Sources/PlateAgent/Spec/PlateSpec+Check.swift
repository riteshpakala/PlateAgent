import Foundation

extension PlateSpec {
    /// The spec with what a model names loosely resolved: an arrow that names a box by its name rather than its
    /// id, a box that names its lane by the lane's name, an id given twice made unique, whitespace trimmed.
    public func normalized() -> PlateSpec {
        var spec = self
        spec.caption = caption.trimmed; spec.title = title.trimmed; spec.subtitle = subtitle.trimmed
        var seenLanes: Set<String> = []
        spec.lanes = lanes.map { lane in
            var lane = lane
            lane.id = Self.unique(lane.id.trimmed.isEmpty ? PlateLoose.slug(lane.name) : lane.id.trimmed, in: &seenLanes)
            lane.name = lane.name.trimmed
            return lane
        }
        var seenNodes: Set<String> = []
        spec.nodes = nodes.map { node in
            var node = node
            node.id = Self.unique(node.id.trimmed.isEmpty ? PlateLoose.slug(node.name) : node.id.trimmed, in: &seenNodes)
            node.name = node.name.trimmed
            node.duty = node.duty?.trimmed.nonEmpty
            node.code = node.code?.trimmed.nonEmpty
            return node
        }
        let laneIDs = Self.resolver(spec.lanes.map { ($0.id, $0.name) })
        let nodeIDs = Self.resolver(spec.nodes.map { ($0.id, $0.name) })
        for i in spec.nodes.indices {
            spec.nodes[i].lane = laneIDs(spec.nodes[i].lane)
            spec.nodes[i].under = spec.nodes[i].under.map(nodeIDs)
        }
        for i in spec.edges.indices {
            spec.edges[i].from = nodeIDs(spec.edges[i].from)
            spec.edges[i].to = nodeIDs(spec.edges[i].to)
            spec.edges[i].label = spec.edges[i].label?.trimmed.nonEmpty
        }
        return spec
    }

    /// Everything a plate cannot hold or cannot draw, one finding each, in an order the model can work down.
    /// Never throws: the findings are the model's next round.
    public func check() -> [PlateFinding] {
        var found: [PlateFinding] = []
        func long(_ text: String?, _ limit: Int, _ element: String, _ what: String) {
            guard let text, text.count > limit else { return }
            found.append(PlateFinding(.limit, element, numbers: [text.count, limit],
                                      "\(what) is \(text.count) characters and holds \(limit): say it in fewer words."))
        }
        if lanes.isEmpty { found.append(PlateFinding(.limit, "lanes", "the plate has no lanes: give it two to six, in the order the thing flows.")) }
        if nodes.isEmpty { found.append(PlateFinding(.limit, "nodes", "the plate has no boxes: put the parts of the system in the lanes.")) }
        if lanes.count > PlateLimits.lanes {
            found.append(PlateFinding(.limit, "lanes", numbers: [lanes.count, PlateLimits.lanes],
                                      "the plate has \(lanes.count) lanes and holds \(PlateLimits.lanes): merge the lanes that are one tier."))
        }
        long(caption, PlateLimits.caption, "caption", "the caption")
        long(title, PlateLimits.title, "title", "the title")
        long(subtitle, PlateLimits.subtitle, "subtitle", "the subtitle")
        long(heading, PlateLimits.heading, "heading", "the heading")
        long(legend, PlateLimits.legend, "legend", "the legend")
        long(tag, PlateLimits.tag, "tag", "the tag")
        let laneIDs = Set(lanes.map(\.id))
        let nodeIDs = Set(nodes.map(\.id))
        for lane in lanes {
            let count = nodes.filter { $0.lane == lane.id }.count
            if count > PlateLimits.nodesPerLane {
                found.append(PlateFinding(.limit, "lane:\(lane.id)", numbers: [count, PlateLimits.nodesPerLane],
                                          "lane \(lane.id) holds \(count) boxes and fits \(PlateLimits.nodesPerLane): split it into two lanes, or draw fewer parts."))
            }
            if count == 0 { found.append(PlateFinding(.limit, "lane:\(lane.id)", "lane \(lane.id) has no boxes: put a box in it, or drop it.")) }
            long(lane.note, PlateLimits.laneNote, "lane:\(lane.id)", "lane \(lane.id)'s note")
        }
        for node in nodes {
            if !laneIDs.contains(node.lane) {
                found.append(PlateFinding(.unknown, "node:\(node.id)", "box \(node.id) sits in lane `\(node.lane)`, which no lane declares: use one of \(lanes.map(\.id).joined(separator: ", "))."))
            }
            if let under = node.under {
                if !nodeIDs.contains(under) || under == node.id {
                    found.append(PlateFinding(.unknown, "node:\(node.id)", "box \(node.id) is under `\(under)`, which is no other box: name a box in its lane, or drop `under`."))
                } else if self.node(under)?.lane != node.lane {
                    found.append(PlateFinding(.unknown, "node:\(node.id)", "box \(node.id) is under \(under), which sits in another lane: a box goes under one in its own lane."))
                }
            }
            long(node.name, PlateLimits.name, "node:\(node.id)", "box \(node.id)'s name")
            long(node.duty, PlateLimits.duty, "node:\(node.id)", "box \(node.id)'s duty")
            long(node.code, PlateLimits.code, "node:\(node.id)", "box \(node.id)'s code line")
        }
        if edges.count > PlateLimits.edges {
            found.append(PlateFinding(.limit, "edges", numbers: [edges.count, PlateLimits.edges],
                                      "the plate has \(edges.count) arrows and holds \(PlateLimits.edges): keep the ones the walk and the reader need."))
        }
        for (i, edge) in edges.enumerated() {
            let element = "edge:\(i + 1)"
            for end in [edge.from, edge.to] where !nodeIDs.contains(end) {
                found.append(PlateFinding(.unknown, element, "arrow \(i + 1) names `\(end)`, which no box declares: use a box's id."))
            }
            if edge.from == edge.to { found.append(PlateFinding(.limit, element, "arrow \(i + 1) goes from \(edge.from) to itself: drop it.")) }
            long(edge.label, PlateLimits.label, element, "arrow \(i + 1)'s label")
        }
        let numbers = edges.compactMap(\.number)
        if numbers.count > PlateLimits.numbers {
            found.append(PlateFinding(.limit, "edges", numbers: [numbers.count, PlateLimits.numbers],
                                      "\(numbers.count) arrows are numbered and the walk holds \(PlateLimits.numbers): number only the one path, end to end."))
        }
        if !numbers.isEmpty, numbers.sorted() != Array(1...numbers.count) {
            found.append(PlateFinding(.limit, "edges", numbers: numbers,
                                      "the numbers are \(numbers.map(String.init).joined(separator: ", ")): number the walk 1 to \(numbers.count), once each, in the order it goes."))
        }
        return found
    }

    /// The spec cut to what a plate holds, so the last round still draws: text past its limit ends in "…", an
    /// arrow or a box with an end nothing declares is dropped, the numbers walk 1 to n.
    public func clamped() -> PlateSpec {
        var spec = normalized()
        spec.caption = spec.caption.cut(PlateLimits.caption)
        spec.title = spec.title.cut(PlateLimits.title)
        spec.subtitle = spec.subtitle.cut(PlateLimits.subtitle)
        spec.heading = spec.heading?.cut(PlateLimits.heading)
        spec.legend = spec.legend?.cut(PlateLimits.legend)
        spec.tag = spec.tag?.cut(PlateLimits.tag)
        spec.lanes = Array(spec.lanes.prefix(PlateLimits.lanes)).map { lane in
            var lane = lane
            lane.note = lane.note?.cut(PlateLimits.laneNote)
            return lane
        }
        let laneIDs = spec.lanes.map(\.id)
        var perLane: [String: Int] = [:]
        spec.nodes = spec.nodes.compactMap { node in
            var node = node
            if !laneIDs.contains(node.lane) { guard let first = laneIDs.first else { return nil }; node.lane = first }
            perLane[node.lane, default: 0] += 1
            guard perLane[node.lane, default: 0] <= PlateLimits.nodesPerLane else { return nil }
            node.name = node.name.cut(PlateLimits.name)
            node.duty = node.duty?.cut(PlateLimits.duty)
            node.code = node.code?.cut(PlateLimits.code)
            return node
        }
        let byID = Dictionary(spec.nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for i in spec.nodes.indices {
            if let under = spec.nodes[i].under, under == spec.nodes[i].id || byID[under]?.lane != spec.nodes[i].lane {
                spec.nodes[i].under = nil
            }
        }
        spec.edges = Array(spec.edges.filter { byID[$0.from] != nil && byID[$0.to] != nil && $0.from != $0.to }.prefix(PlateLimits.edges))
        let walk = spec.edges.indices.filter { spec.edges[$0].number != nil }.sorted { spec.edges[$0].number! < spec.edges[$1].number! }
        for (step, i) in walk.enumerated() { spec.edges[i].number = step < PlateLimits.numbers ? step + 1 : nil }
        for i in spec.edges.indices { spec.edges[i].label = spec.edges[i].label?.cut(PlateLimits.label) }
        return spec
    }

    private static func unique(_ id: String, in seen: inout Set<String>) -> String {
        var candidate = id, n = 2
        while seen.contains(candidate) { candidate = "\(id)-\(n)"; n += 1 }
        seen.insert(candidate)
        return candidate
    }

    /// Resolves a name to an id among `pairs`: the id itself, else an id or name equal to it ignoring case and
    /// punctuation; what matches nothing is kept as written, for `check` to name.
    private static func resolver(_ pairs: [(id: String, name: String)]) -> (String) -> String {
        { raw in
            let text = raw.trimmed
            if pairs.contains(where: { $0.id == text }) { return text }
            let key = PlateLoose.slug(text)
            return pairs.first { PlateLoose.slug($0.id) == key || PlateLoose.slug($0.name) == key }?.id ?? text
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nonEmpty: String? { isEmpty ? nil : self }
    /// At most `limit` characters, the last of them "…" when cut.
    func cut(_ limit: Int) -> String { count <= limit ? self : String(prefix(limit - 1)).trimmed + "…" }
}
