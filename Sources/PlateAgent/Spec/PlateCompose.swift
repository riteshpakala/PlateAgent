import Foundation

/// The plate composed from the model's plan and the code's graph. Each part the plan places is drawn with its duty
/// (the plan's, else the code's own line), its operations as its code line and its agents under it; what starts the
/// parts stands as the front ends; the walk is numbered in order; and the other references among what is drawn are
/// arrows too, labelled with what one part calls on the other.
///
/// PIN: the plan says what; the graph says what is there. A box the plan names that the code does not have is drawn
/// as the plan wrote it, and an arrow the walk names between two boxes is drawn whether or not the graph has it, so a
/// starter can call the root; every other arrow is one the code has.
enum PlateCompose {
    static func spec(_ plan: PlatePlan, graph: PlateGraph) -> PlateSpec {
        let parts = Dictionary(graph.parts.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let starters = Dictionary(graph.starters.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let known = graph.parts.map(\.name) + graph.starters.map(\.name)
        func resolve(_ raw: String) -> String {
            let name = raw.trimmingCharacters(in: .whitespaces)
            if known.contains(name) { return name }
            let lower = name.lowercased()
            if let exact = known.first(where: { $0.lowercased() == lower || PlateLoose.slug($0) == PlateLoose.slug(name) }) { return exact }
            let prefixed = known.filter { $0.lowercased().hasPrefix(lower) }
            return prefixed.count == 1 ? prefixed[0] : name
        }
        // How many mono characters a box's code line holds: a lane beside another is half as wide.
        func width(of lane: PlatePlan.Lane) -> Int {
            guard let index = plan.lanes.firstIndex(of: lane) else { return 40 }
            let half = lane.beside == true || (index + 1 < plan.lanes.count && plan.lanes[index + 1].beside == true)
            return half ? 32 : (lane.boxes.count >= 4 ? 36 : 44)
        }
        var spec = PlateSpec(caption: plan.caption, title: plan.title, subtitle: plan.subtitle, heading: plan.heading, machine: plan.machine,
                             tag: plan.tag, legend: plan.legend)
        var ids: [String: String] = [:]   // a name, as the plan or the graph says it → its box's id
        var kinds: [String: PlateNodeKind] = [:]
        func duty(_ name: String, _ fallback: String?) -> String? {
            (plan.duties[name] ?? plan.duties.first { resolve($0.key) == name }?.value ?? fallback).map { sentence($0, limit: 100) }
        }
        for lane in plan.lanes {
            spec.lanes.append(PlateLane(id: lane.id, name: lane.name, colour: lane.colour, beside: lane.beside, note: lane.note))
            for raw in lane.boxes {
                let name = resolve(raw)
                guard ids[name] == nil else { continue }
                let id = unique(PlateLoose.slug(name), in: Set(ids.values))
                ids[name] = id
                kinds[id] = .service
                if let part = parts[name] {
                    spec.nodes.append(PlateNode(id: id, lane: lane.id, name: name, duty: duty(name, part.what), code: code(part, fits: width(of: lane))))
                    for agent in part.agents {
                        let (word, type) = agentParts(agent)
                        let agentID = unique(PlateLoose.slug(word), in: Set(ids.values))
                        ids[word] = agentID
                        kinds[agentID] = .agent
                        spec.nodes.append(PlateNode(id: agentID, lane: lane.id, name: word, code: plan.duties[word] ?? type, kind: .agent, under: id))
                    }
                } else if let starter = starters[name] {
                    spec.nodes.append(PlateNode(id: id, lane: lane.id, name: name, duty: duty(name, starter.what), code: folder(of: starter.path)))
                } else {
                    spec.nodes.append(PlateNode(id: id, lane: lane.id, name: name, duty: duty(name, nil)))
                }
            }
        }
        for external in plan.externals {
            let host = resolve(external.under)
            guard let hostID = ids[host], let hostNode = spec.nodes.first(where: { $0.id == hostID }), ids[external.name] == nil else { continue }
            let id = unique(PlateLoose.slug(external.name), in: Set(ids.values))
            ids[external.name] = id
            kinds[id] = .external
            spec.nodes.append(PlateNode(id: id, lane: hostNode.lane, name: external.name, code: external.what.map { sentence($0, limit: 40) },
                                        kind: .external, under: hostNode.under ?? hostID))
        }

        // The walk, numbered in order; then each agent's run and each external's wire; then the code's other references.
        var drawn: Set<String> = []
        func key(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "|") }
        func style(_ a: String, _ b: String) -> PlateStroke {
            if kinds[a] == .agent || kinds[b] == .agent { return .dashedGold }
            if kinds[a] == .external || kinds[b] == .external { return .dashedGrey }
            return .solid
        }
        var number = 0
        for step in plan.walk {
            let from = resolve(step.from), to = resolve(step.to)
            guard let a = ids[from] ?? ids[step.from], let b = ids[to] ?? ids[step.to], a != b, !drawn.contains(key(a, b)) else { continue }
            number += 1
            drawn.insert(key(a, b))
            spec.edges.append(PlateEdge(from: a, to: b, label: step.label ?? label(graph, from, to, parts[to]), number: number <= 12 ? number : nil,
                                        style: style(a, b), both: kinds[b] == .external ? true : nil))
        }
        for node in spec.nodes where node.kind == .agent || node.kind == .external {
            guard let host = node.under, !drawn.contains(key(host, node.id)) else { continue }
            drawn.insert(key(host, node.id))
            spec.edges.append(PlateEdge(from: host, to: node.id, style: style(host, node.id), both: node.kind == .external ? true : nil))
        }
        // The code's other references, the most used first, while the plate stays readable: one used more than once,
        // or between neighbouring lanes.
        let laneOrder = Dictionary(plan.lanes.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        func lane(of id: String) -> Int? { spec.nodes.first { $0.id == id }.flatMap { laneOrder[$0.lane] } }
        for reference in graph.references.sorted(by: { $0.count > $1.count }) {
            guard spec.edges.count < 20, let a = ids[reference.from], let b = ids[reference.to], !drawn.contains(key(a, b)),
                  let la = lane(of: a), let lb = lane(of: b), reference.count > 1 || abs(la - lb) <= 1 else { continue }
            drawn.insert(key(a, b))
            spec.edges.append(PlateEdge(from: a, to: b, label: label(graph, reference.from, reference.to, parts[reference.to])))
        }
        // A starter with no arrow yet calls the highest part it names in the lane right under it.
        for starter in graph.starters {
            guard let a = ids[starter.name], !spec.edges.contains(where: { $0.from == a || $0.to == a }), let la = lane(of: a) else { continue }
            let target = starter.parts.compactMap { parts[$0] }.filter { ids[$0.name].flatMap(lane(of:)) == la + 1 }.max { $0.rank < $1.rank }
            if let target, let b = ids[target.name], spec.edges.count < 22 {
                spec.edges.append(PlateEdge(from: a, to: b, colour: .gold))
            }
        }
        return spec
    }

    /// What `from` calls on `to`, two words at most: the calls that are `to`'s own operations first.
    static func label(_ graph: PlateGraph, _ from: String, _ to: String, _ target: PlateGraph.Part?) -> String? {
        guard let reference = graph.references.first(where: { $0.from == from && $0.to == to }), !reference.calls.isEmpty else { return nil }
        let operations = Set((target?.operations ?? []).map { $0.lowercased() })
        let own = reference.calls.filter { operations.contains($0.lowercased()) }
        let chosen = (own.isEmpty ? reference.calls : own).prefix(2).map { $0.prefix(1).lowercased() + $0.dropFirst() }
        return chosen.joined(separator: " · ")
    }

    /// A part's code line: its operations, as many as fit in `fits` characters, else its folder.
    static func code(_ part: PlateGraph.Part, fits: Int = 44) -> String {
        var line = ""
        for operation in part.operations {
            let next = line.isEmpty ? operation : line + " · " + operation
            if next.count > fits { break }
            line = next
        }
        return line.isEmpty ? folder(of: part.path) : line
    }

    /// `Sources/CraftRuntime/Root/CraftRuntimeRoot.swift` → `CraftRuntime/Root`.
    static func folder(of path: String) -> String {
        var parts = path.split(separator: "/").map(String.init)
        if parts.first == "Sources" { parts.removeFirst() }
        if let last = parts.last, last.contains(".") { parts.removeLast() }
        return parts.joined(separator: "/")
    }

    /// `coder (Coder)` → (`coder`, `Coder`).
    static func agentParts(_ agent: String) -> (String, String?) {
        guard let open = agent.firstIndex(of: "("), agent.hasSuffix(")") else { return (agent, nil) }
        return (agent[..<open].trimmingCharacters(in: .whitespaces), String(agent[agent.index(after: open)..<agent.index(before: agent.endIndex)]))
    }

    /// The first sentence of `text`, within `limit`: whole when it fits, else to the last clause that does (a comma,
    /// a colon, a dash), else to a word, with "…".
    static func sentence(_ text: String, limit: Int) -> String {
        let first = PlateGraph.firstSentence(text).trimmed
        guard first.count > limit else { return first }
        let head = String(first.prefix(limit))
        for mark in [" — ", "; ", ": ", ", "] {
            if let range = head.range(of: mark, options: .backwards), head.distance(from: head.startIndex, to: range.lowerBound) >= limit / 2 {
                return String(head[..<range.lowerBound]).trimmed
            }
        }
        let cut = head.prefix(limit - 1)
        return (cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)).trimmed + "…"
    }

    private static func unique(_ id: String, in taken: Set<String>) -> String {
        var candidate = id.isEmpty ? "box" : id, n = 2
        while taken.contains(candidate) { candidate = "\(id)-\(n)"; n += 1 }
        return candidate
    }
}
