import Foundation
import GraniteAgents

/// One call, from the ask to the PNG: read the sources, draft the spec on the host's model, then a round at a time
/// draw it — check, grid, measure, lay out, render, measure again — and hand what was found back to the model to
/// fix, until it measures clean or the rounds are spent. The best round is written: the PNG, the spec inside it.
///
/// PIN: the model decides what the plate says; it never places anything. Where a box goes, how an arrow runs and
/// whether a label is clear are the layout's and WebKit's facts, and what the model hears back is those facts as
/// sentences it can act on.
struct PlateLoop: Sendable {
    let input: PlateAgent.Input
    let context: PlateAgent.Context
    let yield: @Sendable (PlateFrame) -> Void

    func run() async throws -> PlateResult {
        let host = context.host
        let folder = URL(fileURLWithPath: ((input.directory ?? host.directory ?? FileManager.default.currentDirectoryPath) as NSString).expandingTildeInPath)
        let rounds = min(max(input.rounds ?? 3, 1), 6)
        var model: (any AgentHostModel)?
        var spec: PlateSpec
        // With the code's graph, the model plans and the package composes; without one, the model writes the spec.
        var plan: PlatePlan?
        var graph: PlateGraph?
        if let path = input.spec {
            let url = PlateSources.resolve(path, in: folder)
            guard let data = try? Data(contentsOf: url) else { throw PlateError.spec("no file at \(url.path)") }
            // A plate's PNG carries the spec it was drawn from; a JSON is a spec as written.
            let json = url.pathExtension.lowercased() == "png" ? PlatePNG.embedded(in: data).map { Data($0.utf8) } : data
            guard let json else { throw PlateError.spec("\(url.lastPathComponent) carries no plate spec") }
            // An infographic drawn before is drawn again as one.
            if PlateSheet.isSheet(json) {
                let sheet: PlateSheet
                do { sheet = try JSONDecoder().decode(PlateSheet.self, from: json) } catch { throw PlateError.spec("\(error)") }
                return try await self.sheet(sheet, sources: nil, folder: folder, rounds: rounds)
            }
            do { spec = try JSONDecoder().decode(PlateSpec.self, from: json) } catch { throw PlateError.spec("\(error)") }
            model = host.model
            // A spec and a brief: what the brief asks of the plate, made on the spec before it is drawn again.
            if let brief = input.brief, !brief.isEmpty, let model {
                host.note("changing the plate: \(brief.prefix(80))")
                if let changed = try? await ask(model, system: PlateDraft.reviseSystem, user: PlateDraft.change(spec, brief: brief)),
                   !changed.lanes.isEmpty, !changed.nodes.isEmpty {
                    spec = changed
                }
            }
        } else {
            guard let offered = host.model else { throw PlateError.noModel }
            model = offered
            // An infographic named, or no sources to read: nothing of the project's code is drawn.
            let named = PlateForm(loose: input.form)
            let given = !(input.sources ?? []).isEmpty
            if named == .infographic || (named == nil && !given) {
                let sources = given ? PlateSources.read(input.sources ?? [], in: folder) : nil
                if let sources { yield(.read(files: sources.files, characters: sources.digest.count)) }
                return try await sheet(nil, sources: sources, folder: folder, rounds: rounds)
            }
            let sources = PlateSources.read(input.sources ?? [], in: folder)
            yield(.read(files: sources.files, characters: sources.digest.count))
            host.note("read \(sources.files) file\(sources.files == 1 ? "" : "s") under \((input.sources ?? []).joined(separator: ", ").nonEmpty ?? folder.lastPathComponent)")
            // Sources with no code graph are an infographic of what they say, unless the call asked for its architecture.
            if PlateForm.chosen(input.form, graph: sources.graph) == .infographic {
                return try await sheet(nil, sources: sources, folder: folder, rounds: rounds)
            }
            let user = PlateDraft.draft(ask: host.ask, brief: input.brief, project: folder.lastPathComponent, sources: sources)
            if let read = sources.graph, read.parts.count >= 2 {
                graph = read
                host.note("planning the plate from \(read.parts.count) parts and \(read.references.count) references")
                var planned = try await askPlan(offered, system: PlateDraft.planSystem, user: user)
                // What walks is what the entry part is sent, never the part's own name: asked again, of that part alone.
                if let entry = PlateCompose.entry(planned, graph: read), PlateCompose.isStem(planned.unit, of: entry.name, kind: read.kind) {
                    host.note("asking what one \(entry.name) is sent")
                    if let words = try? await askWords(offered, entry: entry, project: read.project ?? folder.lastPathComponent),
                       !PlateCompose.isStem(words.unit, of: entry.name, kind: read.kind) {
                        planned.unit = words.unit ?? planned.unit
                        planned.start = words.start ?? planned.start
                        planned.end = words.end ?? planned.end
                    }
                }
                plan = planned
                spec = PlateCompose.spec(planned, graph: read)
            } else {
                host.note("drafting the plate: lanes, boxes, arrows")
                spec = try await ask(offered, system: PlateDraft.draftSystem, user: user)
            }
            yield(.drafted(spec))
        }
        guard !spec.lanes.isEmpty, !spec.nodes.isEmpty else {
            throw PlateError.empty(spec.lanes.isEmpty ? "no lanes" : "no boxes")
        }

        var best: (spec: PlateSpec, rendered: PlateRendered, findings: [PlateFinding], round: Int)?
        var last = 0
        for round in 1...rounds {
            try Task.checkCancellation()
            last = round
            let normal = spec.normalized()
            let checked = normal.check()
            var drawn = PlateLayout.pruned(PlateLayout.cleared(PlateOrder.ordered(normal.clamped())))
            var (rendered, found) = try await draw(drawn, checked: checked, round: round, plan: plan)
            // What the package can fix itself it fixes before the model hears of it.
            for _ in 0..<2 {
                guard let tidied = Self.tidied(drawn, findings: found) else { break }
                drawn = tidied
                (rendered, found) = try await draw(drawn, checked: checked, round: round, plan: plan)
            }
            yield(.measured(round: round, findings: found))
            host.note(found.isEmpty ? "round \(round): measured clean" : "round \(round): \(found.count) to fix — \(found[0].sentence)")
            if best == nil || found.count <= best!.findings.count { best = (drawn, rendered, found, round) }
            // The model revises what its words decide; where a box sits and how an arrow runs are the layout's.
            guard found.contains(where: { ![.crossing, .overlap].contains($0.kind) }), round < rounds, let model else { break }
            if let current = plan, let graph {
                host.note("revising the plan")
                guard let revised = try? await askPlan(model, system: PlateDraft.planReviseSystem, user: PlateDraft.revise(current, findings: found)),
                      !revised.lanes.isEmpty else { break }
                plan = revised
                spec = PlateCompose.spec(revised, graph: graph)
            } else {
                host.note("revising the spec")
                guard let revised = try? await ask(model, system: PlateDraft.reviseSystem, user: PlateDraft.revise(normal, findings: found)),
                      !revised.lanes.isEmpty, !revised.nodes.isEmpty else { break }
                spec = revised
            }
            yield(.revised(round: round))
        }
        guard let best else { throw PlateError.render("no round drew") }
        return try write(best.spec, best.rendered, findings: best.findings, rounds: last, folder: folder)
    }

    /// One drawing of `drawn`: grid, measure, lay out, render, measure again.
    private func draw(_ drawn: PlateSpec, checked: [PlateFinding], round: Int, plan: PlatePlan?) async throws -> (PlateRendered, [PlateFinding]) {
        let grid = PlateGrid.make(drawn)
        let measures = try await context.compute.measures(drawn, grid: grid)
        let layout = PlateLayout.make(drawn, grid: grid, measures: measures)
        let html = layout.page(drawn, faces: try await context.compute.faces())
        Self.keep(html, round: round, plan: plan)
        let rendered = try await context.compute.render(html)
        return (rendered, checked + layout.findings + PlateMeasure.findings(rendered.raw, spec: drawn))
    }

    /// The drawn spec with what the package fixes itself fixed, or nil when nothing it found is its to fix: a label
    /// drawn over a box or another label, on an arrow the walk does not number, is dropped; the arrow stays.
    static func tidied(_ spec: PlateSpec, findings: [PlateFinding]) -> PlateSpec? {
        var spec = spec
        var changed = false
        // A code line wider than its box loses operations from its end until it fits: it lists them, most used first.
        for finding in findings where finding.kind == .overflow && finding.element.hasPrefix("node:") && finding.sentence.contains("code line") {
            guard let i = spec.nodes.firstIndex(where: { "node:" + $0.id == finding.element }), let code = spec.nodes[i].code,
                  finding.numbers.count == 2, finding.numbers[0] > 0 else { continue }
            var parts = code.components(separatedBy: " · ")
            let fits = Int(Double(code.count) * Double(finding.numbers[1]) / Double(finding.numbers[0]))
            while parts.count > 1, parts.joined(separator: " · ").count > fits { parts.removeLast() }
            guard parts.joined(separator: " · ") != code else { continue }
            spec.nodes[i].code = parts.joined(separator: " · ")
            changed = true
        }
        for finding in findings where finding.kind == .overlap {
            for element in [finding.element, finding.other].compactMap({ $0 }) where element.hasPrefix("wire:") {
                guard let n = Int(element.dropFirst(5)), spec.edges.indices.contains(n - 1), spec.edges[n - 1].number == nil,
                      spec.edges[n - 1].label != nil else { continue }
                spec.edges[n - 1].label = nil
                changed = true
            }
        }
        return changed ? spec : nil
    }

    /// The walk's three words, asked of the part the walk enters alone: what it is sent, what starts one, what one leaves.
    private func askWords(_ model: any AgentHostModel, entry: PlateGraph.Part, project: String) async throws -> PlatePlan {
        let stem = PlateCompose.stem(entry.name, kind: nil)
        let user = """
        In \(project), a flow enters \(entry.name).
        What it says it is: \(entry.what ?? "(no line)")
        Its operations: \(entry.operations.joined(separator: ", "))
        One \(entry.name) holds many of what it is sent, one after another. In the code's own words, one or two words each, lowercase:
        - `unit`: what is one of those? Never "\(stem)".
        - `start`: what does a person give it to begin one?
        - `end`: what does one leave behind for the next?
        """
        let schema = Data(#"{"type":"object","required":["unit","start","end"],"properties":{"unit":{"type":"string"},"start":{"type":"string"},"end":{"type":"string"}}}"#.utf8)
        let data = try await model.object(schema: schema, system: "You name what flows through one part of a software system. Answer with one compact JSON object.",
                                          user: user, maxTokens: 120, seconds: 60)
        return try JSONDecoder().decode(PlatePlan.self, from: data)
    }

    private func askPlan(_ model: any AgentHostModel, system: String, user: String) async throws -> PlatePlan {
        let data = try await model.object(schema: PlateDraft.planSchema, system: system, user: user, maxTokens: 3_000, seconds: 300)
        do {
            return try JSONDecoder().decode(PlatePlan.self, from: data)
        } catch {
            throw AgentHostError.answer("\(error)")
        }
    }

    private func ask(_ model: any AgentHostModel, system: String, user: String) async throws -> PlateSpec {
        let data = try await model.object(schema: PlateDraft.schema, system: system, user: user, maxTokens: 6_000, seconds: 420)
        do {
            return try JSONDecoder().decode(PlateSpec.self, from: data)
        } catch {
            throw AgentHostError.answer("\(error)")
        }
    }

    /// The PNG, carrying the spec it was drawn from, where `output` says or where a project keeps its pictures.
    private func write(_ spec: PlateSpec, _ rendered: PlateRendered, findings: [PlateFinding], rounds: Int, folder: URL) throws -> PlateResult {
        let png = Self.output(input.output, folder: folder, title: spec.title)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let json = (try? encoder.encode(spec)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        do {
            try FileManager.default.createDirectory(at: png.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PlatePNG.embedding(json, in: rendered.png).write(to: png)
        } catch { throw PlateError.unwritable(png.path) }
        return PlateResult(path: png.path, paths: [png.path], width: rendered.width, height: rendered.height, rounds: rounds,
                           findings: findings.map(\.sentence), title: spec.title, lanes: spec.lanes.count, nodes: spec.nodes.count,
                           edges: spec.edges.count)
    }

    /// `output` under the folder, a `.png` added when it has no extension; else the project's pictures folder
    /// (docs/README_Assets, then docs), else the folder itself, named for the title.
    static func output(_ path: String?, folder: URL, title: String) -> URL {
        if let path, !path.isEmpty {
            let url = PlateSources.resolve(path, in: folder)
            return url.pathExtension.isEmpty ? url.appendingPathExtension("png") : url
        }
        let slug = String(PlateLoose.slug(title).prefix(48)).nonEmpty ?? "plate"
        let manager = FileManager.default
        for candidate in ["docs/README_Assets", "Docs/README_Assets", "docs", "Docs"] {
            var isFolder: ObjCBool = false
            let url = folder.appendingPathComponent(candidate)
            if manager.fileExists(atPath: url.path, isDirectory: &isFolder), isFolder.boolValue { return url.appendingPathComponent(slug + ".png") }
        }
        return folder.appendingPathComponent(slug + ".png")
    }

    /// `PLATE_HTML=<folder>` keeps each round's page there, to open in a browser, and the plan it was composed from:
    /// never beside the PNG, where a host that indexes HTML as code would read it.
    static func keep(_ html: String, round: Int, plan: PlatePlan?) {
        guard let dir = ProcessInfo.processInfo.environment["PLATE_HTML"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try? html.write(to: url.appendingPathComponent("plate-round-\(round).html"), atomically: true, encoding: .utf8)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let plan, let json = try? encoder.encode(plan) { try? json.write(to: url.appendingPathComponent("plate-round-\(round).plan.json")) }
    }
}
