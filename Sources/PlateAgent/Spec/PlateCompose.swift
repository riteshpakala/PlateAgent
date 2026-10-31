import Foundation

/// The plate composed from the model's plan and the code's graph. The front ends and the root come from the graph, in
/// the top two lanes; the plan's lanes hold the parts below, and a part it left out goes beside the part it works with
/// most. Each part is drawn with its duty (the plan's, else the code's own line), its operations as its code line and
/// its agents under it; the walk is numbered in order; the other references among what is drawn are arrows too,
/// labelled with what one part calls on the other; and the header is the plates' own, made of three words the plan
/// gives (`header`).
///
/// PIN: the plan says what; the graph says what is there. A box the plan names that the code does not have is drawn
/// as the plan wrote it, and an arrow the walk names between two boxes is drawn whether or not the graph has it, so a
/// starter can call the root; every other arrow is one the code has. What a plate's house style decides (the top
/// lanes, the header's form, the legend) is never left to the model, which copies the example it is shown.
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
        let lanes = Self.lanes(plan, graph: graph, resolve: resolve)
        // How many mono characters a box's code line holds, and how many a duty's two lines do: a lane beside another
        // is half as wide and sets its boxes two by two.
        func half(_ lane: PlatePlan.Lane) -> Bool {
            guard let index = lanes.firstIndex(of: lane) else { return false }
            return lane.beside == true || (index + 1 < lanes.count && lanes[index + 1].beside == true)
        }
        func width(of lane: PlatePlan.Lane) -> Int { half(lane) ? 32 : (lane.boxes.count >= 4 ? 36 : 44) }
        func dutyLimit(of lane: PlatePlan.Lane) -> Int {
            let across = Double(max(1, half(lane) ? min(2, lane.boxes.count) : min(4, lane.boxes.count)))
            let line = Int(((half(lane) ? 640.0 : 1330.0) / across - 40) / 7.4)
            return min(110, 2 * line - 4)
        }
        var spec = PlateSpec(caption: "", title: "", subtitle: "")
        var ids: [String: String] = [:]   // a name, as the plan or the graph says it → its box's id
        var kinds: [String: PlateNodeKind] = [:]
        // The plan's duty, unless it echoes the worked example; else the code's own line.
        func duty(_ name: String, _ fallback: String?, in lane: PlatePlan.Lane) -> String? {
            let planned = (plan.duties[name] ?? plan.duties.first { resolve($0.key) == name }?.value).flatMap { PlateDraft.echoes($0) ? nil : $0 }
            return (planned ?? fallback.map(plain)).map { sentence($0, limit: dutyLimit(of: lane)) }
        }
        for lane in lanes {
            spec.lanes.append(PlateLane(id: lane.id, name: lane.name, colour: lane.colour, beside: lane.beside,
                                        note: lane.note.flatMap { PlateDraft.echoes($0) ? nil : $0 }))
            for name in lane.boxes {
                guard ids[name] == nil else { continue }
                let id = unique(PlateLoose.slug(name), in: Set(ids.values))
                ids[name] = id
                kinds[id] = .service
                if let part = parts[name] {
                    spec.nodes.append(PlateNode(id: id, lane: lane.id, name: name, duty: duty(name, part.what, in: lane), code: code(part, fits: width(of: lane))))
                    for agent in part.agents {
                        let (word, type) = agentParts(agent)
                        let agentID = unique(PlateLoose.slug(word), in: Set(ids.values))
                        ids[word] = agentID
                        if let type, ids[type] == nil { ids[type] = agentID }
                        kinds[agentID] = .agent
                        spec.nodes.append(PlateNode(id: agentID, lane: lane.id, name: word, code: type, kind: .agent, under: id))
                    }
                } else if let starter = starters[name] {
                    spec.nodes.append(PlateNode(id: id, lane: lane.id, name: name, duty: duty(name, starter.what, in: lane), code: folder(of: starter.path)))
                } else {
                    spec.nodes.append(PlateNode(id: id, lane: lane.id, name: name, duty: duty(name, nil, in: lane)))
                }
            }
        }
        for external in plan.externals {
            let host = resolve(external.under)
            // An agent is drawn under its part already: an external named for one, or whose line names one (`Coder`,
            // `WatchAgent`, "coder agent: runs turns"), is that agent.
            let said = (external.name + " " + (external.what ?? "")).lowercased()
            if let agent = ids.first(where: { kinds[$0.value] == .agent && (said.split { !$0.isLetter }.contains(Substring($0.key.lowercased()))) }) {
                if ids[external.name] == nil { ids[external.name] = agent.value }
                continue
            }
            guard let hostID = ids[host], let hostNode = spec.nodes.first(where: { $0.id == hostID }), ids[external.name] == nil else { continue }
            let id = unique(PlateLoose.slug(external.name), in: Set(ids.values))
            ids[external.name] = id
            kinds[id] = .external
            // In the row beside its part while the lane has room (a full lane of four, or a lane beside another, hangs it
            // under the part).
            let lanePlan = lanes.first { $0.id == hostNode.lane }
            let inRow = spec.nodes.filter { $0.lane == hostNode.lane && $0.under == nil }.count
            let beside = lanePlan.map { !half($0) } == true && inRow < 4 && hostNode.under == nil
            spec.nodes.append(PlateNode(id: id, lane: hostNode.lane, name: external.name, code: external.what.map { sentence($0, limit: 40) },
                                        kind: .external, under: beside ? nil : hostNode.under ?? hostID))
        }

        // The walk, numbered in order; then each agent's run and each external's wire; then the code's other references.
        var drawn: Set<String> = []
        func key(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "|") }
        func style(_ a: String, _ b: String) -> PlateStroke {
            if kinds[a] == .agent || kinds[b] == .agent { return .dashedGold }
            if kinds[a] == .external || kinds[b] == .external { return .dashedGrey }
            return .solid
        }
        let laneOrder = Dictionary(lanes.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        func lane(of id: String) -> Int? { spec.nodes.first { $0.id == id }.flatMap { laneOrder[$0.lane] } }
        func colour(of id: String) -> PlateColour? { spec.nodes.first { $0.id == id }.flatMap { node in lanes.first { $0.id == node.lane }?.colour } }
        var number = 0
        var lastTarget: String?
        for step in Self.walk(plan, graph: graph, lanes: lanes, resolve: resolve) {
            let from = resolve(step.from), to = resolve(step.to)
            guard let a = ids[from] ?? ids[step.from], let b = ids[to] ?? ids[step.to], a != b, !drawn.contains(key(a, b)) else { continue }
            // Two ways into one box, one after the other (the app and the command line into the root), share a number.
            if b != lastTarget { number += 1 }
            lastTarget = b
            drawn.insert(key(a, b))
            // The walk leaves the front ends and the root in gold, as the plate's own numbers are.
            let gold = colour(of: a) == .dial && lane(of: a) != lane(of: b) && style(a, b) == .solid
            let called = starters[from]?.calls[to].flatMap { $0.isEmpty ? nil : $0.prefix(3).joined(separator: " · ") }
            spec.edges.append(PlateEdge(from: a, to: b, label: step.label ?? called ?? label(graph, from, to, parts[to]), number: number <= 12 ? number : nil,
                                        style: style(a, b), colour: gold ? .gold : nil, both: kinds[b] == .external ? true : nil))
        }
        for node in spec.nodes where node.kind == .agent || node.kind == .external {
            guard let host = node.under ?? plan.externals.first(where: { $0.name == node.name }).flatMap({ ids[resolve($0.under)] }),
                  !drawn.contains(key(host, node.id)) else { continue }
            drawn.insert(key(host, node.id))
            spec.edges.append(PlateEdge(from: host, to: node.id, style: style(host, node.id), both: node.kind == .external ? true : nil))
        }
        // The code's other references, the most used first, while the plate stays readable: one used more than once,
        // or between neighbouring lanes.
        for reference in graph.references.sorted(by: { $0.count > $1.count }) {
            guard spec.edges.count < 20, let a = ids[reference.from], let b = ids[reference.to], !drawn.contains(key(a, b)),
                  let la = lane(of: a), let lb = lane(of: b), reference.count > 1 || abs(la - lb) <= 1 else { continue }
            drawn.insert(key(a, b))
            spec.edges.append(PlateEdge(from: a, to: b, label: label(graph, reference.from, reference.to, parts[reference.to])))
        }
        // A front end reaches what it starts: the root below it in gold, a service it holds beside it.
        for starter in graph.starters {
            guard let a = ids[starter.name], let la = lane(of: a) else { continue }
            for reached in starter.reaches {
                guard let b = ids[reached], !drawn.contains(key(a, b)), let lb = lane(of: b) else { continue }
                drawn.insert(key(a, b))
                let called = starter.calls[reached].flatMap { $0.isEmpty ? nil : $0.prefix(3).joined(separator: " · ") }
                spec.edges.append(PlateEdge(from: a, to: b, label: la == lb ? nil : called, colour: la == lb ? nil : .gold))
            }
        }
        // A starter with no arrow yet calls the highest part it names in the lane right under it.
        for starter in graph.starters {
            guard let a = ids[starter.name], !spec.edges.contains(where: { $0.from == a || $0.to == a }), let la = lane(of: a) else { continue }
            let target = starter.parts.compactMap { parts[$0] }.filter { ids[$0.name].flatMap(lane(of:)) == la + 1 }.max { $0.rank < $1.rank }
            if let target, let b = ids[target.name], spec.edges.count < 22 {
                spec.edges.append(PlateEdge(from: a, to: b, colour: .gold))
            }
        }
        header(&spec, plan: plan, graph: graph, names: Array(ids.keys))
        return spec
    }

    // MARK: Lanes

    /// The lanes: the front ends and the root from the graph, then the plan's lanes of parts, each part once, a part the
    /// plan left out beside the part it works with most, at most six lanes in all.
    static func lanes(_ plan: PlatePlan, graph: PlateGraph, resolve: (String) -> String) -> [PlatePlan.Lane] {
        var top: [PlatePlan.Lane] = []
        var reserved: Set<String> = []
        if let root = graph.root {
            let entries = graph.starters.filter { $0.role == .entry }
            let ordered = entries.filter { !$0.name.hasSuffix(".app") } + entries.filter { $0.name.hasSuffix(".app") }
            let roots = graph.starters.filter { $0.role == .file && $0.name != root && !$0.reaches.isEmpty }
            let held = graph.starters.filter { $0.role == .held }
            let front = Array((ordered + roots + held).map(\.name).prefix(4))
            let note = plan.rootNote ?? plan.lanes.first { $0.boxes.map(resolve).contains(root) }?.note
            if !front.isEmpty { top.append(PlatePlan.Lane(id: "front", name: "the front ends", colour: .dial, boxes: front)) }
            top.append(PlatePlan.Lane(id: "root", name: "the root", colour: .dial, note: note, boxes: [root]))
            reserved = Set(front + [root])
        }
        let partNames = graph.parts.map(\.name)
        var placed = reserved
        var lanes: [PlatePlan.Lane] = []
        var loose: [String] = []
        for var lane in plan.lanes {
            let named = lane.boxes.map(resolve)
            let boxes = named.filter { !placed.contains($0) }
            // A lane the plan gave a front end or the root is the top lanes': its parts are placed again below.
            if named.contains(where: reserved.contains) {
                loose += boxes.filter { partNames.contains($0) && !loose.contains($0) }
                continue
            }
            guard !boxes.isEmpty else { continue }
            lane.boxes = boxes
            placed.formUnion(boxes)
            if (!top.isEmpty && (lane.id == "front" || lane.id == "root")) || lanes.contains(where: { $0.id == lane.id }) { lane.id += "-\(lanes.count + 1)" }
            lanes.append(lane)
        }
        // Every part has a lane: one the plan left out goes where the part it refers to most, or is referred to by, sits.
        let byRank = graph.parts.sorted { $0.rank > $1.rank }.map(\.name)
        let missing = loose.filter { !placed.contains($0) } + byRank.filter { !placed.contains($0) && !loose.contains($0) }
        for name in missing {
            let partners = graph.references.filter { $0.from == name || $0.to == name }.sorted { $0.count > $1.count }
                .map { $0.from == name ? $0.to : $0.from }
            let room = { (i: Int) in lanes[i].boxes.count < 4 }
            if let i = partners.lazy.compactMap({ partner in lanes.firstIndex { $0.boxes.contains(partner) } }).first(where: room)
                ?? lanes.indices.last(where: room) {
                lanes[i].boxes.append(name)
            } else {
                lanes.append(PlatePlan.Lane(id: "parts-\(lanes.count + 1)", name: "the rest", colour: .violet, boxes: [name]))
            }
            placed.insert(name)
        }
        // At most six lanes: the two smallest neighbours below the walk's first lane join.
        while top.count + lanes.count > PlateLimits.lanes {
            let pairs = lanes.indices.dropFirst().dropLast().map { ($0, lanes[$0].boxes.count + lanes[$0 + 1].boxes.count) }.filter { $0.1 <= 8 }
            guard let (i, _) = pairs.min(by: { $0.1 < $1.1 }) else { break }
            lanes[i].boxes += lanes[i + 1].boxes
            lanes.remove(at: i + 1)
        }
        // A lane of parts is never dial, the frame's colour; the walk's lane opens the parts on its own; and the last two,
        // when each holds two to four, sit beside each other.
        let palette: [PlateColour] = [.blue, .green, .orange, .violet, .red]
        for i in lanes.indices where lanes[i].colour == .dial && lanes[i].boxes.allSatisfy(partNames.contains) {
            lanes[i].colour = palette.first { colour in !lanes.contains { $0.colour == colour } } ?? .violet
        }
        for i in lanes.indices where lanes[i].beside == true && (i == 0 || lanes[i - 1].beside == true) { lanes[i].beside = nil }
        if lanes.count >= 3, (2...4).contains(lanes[lanes.count - 2].boxes.count), (2...4).contains(lanes[lanes.count - 1].boxes.count),
           lanes[lanes.count - 2].beside != true {
            lanes[lanes.count - 1].beside = true
        }
        // The walk's lane is named for what walks, as the header is; a name the worked example gave is not this plan's.
        let exampleLanes = PlateDraft.exampleLanes
        for i in lanes.indices where exampleLanes.contains(lanes[i].name.lowercased()) {
            lanes[i].name = i == lanes.count - 1 && i > 0 ? "what all share" : "what each keeps"
        }
        if !lanes.isEmpty {
            let unit = header(word: plan.unit, fallback: "request")
            lanes[0].name = ("aeiou".contains(unit.first ?? "x") ? "an " : "a ") + unit
        }
        return top + lanes
    }

    /// The walk as the plate numbers it: it starts where a person starts it, each front end into the root (one number
    /// for both), whether or not the plan said so; a step between two front ends is their wiring, not the walk.
    static func walk(_ plan: PlatePlan, graph: PlateGraph, lanes: [PlatePlan.Lane], resolve: (String) -> String) -> [PlatePlan.Step] {
        guard let root = graph.root, let front = lanes.first(where: { $0.id == "front" }) else { return plan.walk }
        let fronts = Set(front.boxes)
        let steps = plan.walk.filter { !(fronts.contains(resolve($0.from)) && fronts.contains(resolve($0.to))) }
        let into = steps.filter { fronts.contains(resolve($0.from)) && resolve($0.to) == root }
        let entering = graph.starters.filter { fronts.contains($0.name) && $0.reaches.contains(root) }
            .filter { starter in !into.contains { resolve($0.from) == starter.name } }
            .map { PlatePlan.Step(from: $0.name, to: root) }
        return into + entering + steps.filter { step in !into.contains(step) }
    }

    // MARK: Header

    /// The plates' own header and legend, made of the plan's words: what walks (`unit`), where it starts and what it
    /// leaves (`start`, `end`), what the plate shows (`subject`), and the code's kind of part. "One turn, every
    /// service"; "from the ask to the records: what each service is responsible for, in the order a turn passes through
    /// it". A header the plan writes itself is kept unless it echoes the worked example.
    /// One of the plan's header words, plain: lowercased, its article dropped, never the worked example's.
    static func header(word text: String?, fallback: String) -> String {
        var said = (text ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        for article in ["a ", "an ", "the ", "one "] where said.hasPrefix(article) { said = String(said.dropFirst(article.count)) }
        return said.isEmpty || said.count > 24 || PlateDraft.exampleWords.contains(said) ? fallback : said
    }

    static func header(_ spec: inout PlateSpec, plan: PlatePlan, graph: PlateGraph, names: [String]) {
        func word(_ text: String?, _ fallback: String) -> String { header(word: text, fallback: fallback) }
        func article(_ word: String) -> String { "aeiou".contains(word.first ?? "x") ? "an" : "a" }
        func own(_ text: String?) -> String? { text.flatMap { $0.isEmpty || PlateDraft.echoes($0) ? nil : $0 } }
        let kind = (graph.kind ?? "part").lowercased()
        let kinds = kind.hasSuffix("s") ? kind + "es" : kind.hasSuffix("y") ? String(kind.dropLast()) + "ies" : kind + "s"
        let unit = word(plan.unit, "request"), start = word(plan.start, "start"), end = word(plan.end, "end")
        let subject = word(plan.subject, "flow")
        let project = graph.project ?? "the project"
        spec.caption = own(plan.caption) ?? "RAO STUDIOS · \(project.uppercased()) · THE \(subject.uppercased())"
        spec.title = own(plan.title) ?? "One \(unit), every \(kind)"
        spec.subtitle = own(plan.subtitle) ?? "from the \(start) to the \(end): what each \(kind) is responsible for, in the order \(article(unit)) \(unit) passes through it"
        spec.heading = own(plan.heading) ?? "\(article(unit).capitalized) \(unit), through the \(kinds)"
        spec.machine = own(plan.machine) ?? "ONE \(start.uppercased()), END TO END"
        // Where every box lives: the top folders of the parts and the front ends drawn.
        let paths = names.compactMap { name in graph.parts.first { $0.name == name }?.path ?? graph.starters.first { $0.name == name }?.path }
        var folders: [String] = []
        for path in paths {
            let components = path.split(separator: "/")
            let top = components.first == "Sources" && components.count > 1 ? components.prefix(2).joined(separator: "/") : String(components.first ?? "")
            if !top.isEmpty, !folders.contains(top) { folders.append(top) }
        }
        folders.sort()
        let listed = folders.count > 1 ? folders.dropLast().joined(separator: ", ") + " and " + folders.last! : folders.first ?? project
        let agents = spec.nodes.contains { $0.kind == .agent }
        spec.tag = own(plan.tag) ?? "every box is \(article(kind)) \(kind)\(agents ? " or an agent" : "") in \(listed)"
        let granite = graph.conformance?.hasPrefix("Granite") == true
        var legend = "Each box is \(article((graph.conformance ?? kind).lowercased())) **\(graph.conformance ?? kind)**; its line says what it is responsible for, and nothing else is. "
            + "Solid arrows are \(granite ? "dispatches down the relay graph" : "calls")"
        if spec.edges.contains(where: { $0.style == .dashedGold }) { legend += "; {gold:dashed gold} is an agent's run and what it writes" }
        if spec.edges.contains(where: { $0.style == .dashedGrey }) { legend += "; dashed grey is a process across a wire" }
        spec.legend = own(plan.legend) ?? legend + ". The numbers walk one \(unit)."
    }

    // MARK: Words

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

    /// The code's own line as a duty: what the part is, with the code's asides (", as a service", "as Granite state")
    /// and the clause after a dash left out, lowercased as the plate's duties are.
    static func plain(_ what: String) -> String {
        var text = PlateGraph.firstSentence(what)
        text = text.replacingOccurrences(of: #",? as (?:a |an |the )?(?:service|Granite state|Granite app)\b,?"#, with: "", options: .regularExpression)
        if let dash = text.range(of: " — "), text.distance(from: text.startIndex, to: dash.lowerBound) >= 24 { text = String(text[..<dash.lowerBound]) }
        text = text.trimmingCharacters(in: .whitespaces)
        if let first = text.first, first.isUppercase, let word = text.split(separator: " ").first,
           word == "A" || (word.count > 1 && word.dropFirst().allSatisfy(\.isLowercase)) {
            text = first.lowercased() + text.dropFirst()
        }
        return text
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
