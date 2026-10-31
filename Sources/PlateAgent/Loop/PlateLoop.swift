import Foundation
import GraniteAgents

/// One call, from the ask to the PNG: read the sources, draft the spec on the host's model, then a round at a time
/// draw it — check, grid, measure, lay out, render, measure again — and hand what was found back to the model to
/// fix, until it measures clean or the rounds are spent. The best round is written: the PNG, and the spec beside it.
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
        if let path = input.spec {
            let url = PlateSources.resolve(path, in: folder)
            guard let data = try? Data(contentsOf: url) else { throw PlateError.spec("no file at \(url.path)") }
            do { spec = try JSONDecoder().decode(PlateSpec.self, from: data) } catch { throw PlateError.spec("\(error)") }
            model = host.model
        } else {
            guard let offered = host.model else { throw PlateError.noModel }
            model = offered
            let sources = PlateSources.read(input.sources ?? [], in: folder)
            yield(.read(files: sources.files, characters: sources.digest.count))
            host.note("read \(sources.files) file\(sources.files == 1 ? "" : "s") under \((input.sources ?? []).joined(separator: ", ").nonEmpty ?? folder.lastPathComponent)")
            host.note("drafting the plate: lanes, boxes, arrows")
            spec = try await ask(offered, system: PlateDraft.draftSystem,
                                 user: PlateDraft.draft(ask: host.ask, brief: input.brief, project: folder.lastPathComponent, sources: sources))
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
            let drawn = PlateOrder.ordered(normal.clamped())
            let grid = PlateGrid.make(drawn)
            let measures = try await context.compute.measures(drawn, grid: grid)
            let layout = PlateLayout.make(drawn, grid: grid, measures: measures)
            let html = layout.page(drawn, faces: try await context.compute.faces())
            Self.keep(html, round: round)
            let rendered = try await context.compute.render(html)
            let found = checked + layout.findings + PlateMeasure.findings(rendered.raw, spec: drawn)
            yield(.measured(round: round, findings: found))
            host.note(found.isEmpty ? "round \(round): measured clean" : "round \(round): \(found.count) to fix — \(found[0].sentence)")
            if best == nil || found.count <= best!.findings.count { best = (drawn, rendered, found, round) }
            guard !found.isEmpty, round < rounds, let model else { break }
            host.note("revising the spec")
            guard let revised = try? await ask(model, system: PlateDraft.reviseSystem, user: PlateDraft.revise(normal, findings: found)),
                  !revised.lanes.isEmpty, !revised.nodes.isEmpty else { break }
            spec = revised
            yield(.revised(round: round))
        }
        guard let best else { throw PlateError.render("no round drew") }
        return try write(best.spec, best.rendered, findings: best.findings, rounds: last, folder: folder)
    }

    private func ask(_ model: any AgentHostModel, system: String, user: String) async throws -> PlateSpec {
        let data = try await model.object(schema: PlateDraft.schema, system: system, user: user, maxTokens: 6_000, seconds: 420)
        do {
            return try JSONDecoder().decode(PlateSpec.self, from: data)
        } catch {
            throw AgentHostError.answer("\(error)")
        }
    }

    /// The PNG and the spec beside it, where `output` says or where a project keeps its pictures.
    private func write(_ spec: PlateSpec, _ rendered: PlateRendered, findings: [PlateFinding], rounds: Int, folder: URL) throws -> PlateResult {
        let png = Self.output(input.output, folder: folder, title: spec.title)
        let json = png.deletingPathExtension().appendingPathExtension("plate.json")
        do {
            try FileManager.default.createDirectory(at: png.deletingLastPathComponent(), withIntermediateDirectories: true)
            try rendered.png.write(to: png)
        } catch { throw PlateError.unwritable(png.path) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do { try encoder.encode(spec).write(to: json) } catch { throw PlateError.unwritable(json.path) }
        return PlateResult(path: png.path, paths: [png.path, json.path], width: rendered.width, height: rendered.height, rounds: rounds,
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

    /// `PLATE_HTML=<folder>` keeps each round's page there, to open in a browser: never beside the PNG, where a
    /// host that indexes HTML as code would read it.
    private static func keep(_ html: String, round: Int) {
        guard let dir = ProcessInfo.processInfo.environment["PLATE_HTML"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try? html.write(to: url.appendingPathComponent("plate-round-\(round).html"), atomically: true, encoding: .utf8)
    }
}
