import Foundation
import GraniteAgents

/// An infographic, from the ask to the PNG: drafted on the host's model, or drawn again from a plate's own spec and
/// changed as a brief asks; then a round at a time drawn, measured and handed back to the model to fix, until it
/// measures clean or the rounds are spent. The best round is written: the PNG, the sheet inside it.
///
/// PIN: THE MODEL SAYS, THE KIT PLACES, as for a flow plate. The model writes blocks and their words; the grid, the
/// type and the colours are the kit's, and what the model hears back is what the page measured.
extension PlateLoop {
    func sheet(_ given: PlateSheet?, sources: PlateSources?, folder: URL, rounds: Int) async throws -> PlateResult {
        let host = context.host
        let model = host.model
        // Who the person named: the speakers a quote may credit (`PlateSheet.speakers`). The brief is the calling
        // model's words when there is an ask, so it names no one then. A plate drawn again keeps its speakers.
        let grounds = ([host.ask ?? input.brief, sources?.digest] + (given?.blocks.map(\.by) ?? [])).compactMap { $0 }.joined(separator: "\n")
        var sheet: PlateSheet
        if var given {
            if let brief = input.brief, !brief.isEmpty, let model {
                host.note("changing the plate: \(brief.prefix(80))")
                if let changed = try? await askSheet(model, system: PlateSheetDraft.reviseSystem, user: PlateSheetDraft.change(given, brief: brief)),
                   !changed.blocks.isEmpty {
                    given = changed
                }
            }
            sheet = given
        } else {
            guard let model else { throw PlateError.noModel }
            host.note("drafting an infographic: its header and blocks")
            sheet = try await askSheet(model, system: PlateSheetDraft.system,
                                       user: PlateSheetDraft.draft(ask: host.ask, brief: input.brief, project: folder.lastPathComponent, sources: sources))
            yield(.sketched(sheet))
        }
        guard !sheet.blocks.isEmpty else { throw PlateError.empty("no blocks") }

        var best: (sheet: PlateSheet, rendered: PlateRendered, findings: [PlateFinding])?
        var last = 0
        for round in 1...rounds {
            try Task.checkCancellation()
            last = round
            // Drawn clamped, so a model past a limit still gets its plate; told of the limit, so the words get fixed.
            // Drawn with only the speakers the person named; told of the others.
            let drawn = sheet.clamped().attributed(to: grounds)
            let html = PlateSheetKit.page(drawn, faces: try await context.compute.faces())
            Self.keep(html, round: round, plan: nil)
            let rendered = try await context.compute.render(html)
            let found = sheet.check() + sheet.speakers(named: grounds) + PlateSheetDraft.echoes(sheet)
                + PlateMeasure.findings(rendered.raw, sheet: drawn, height: Double(rendered.height) / 2)
            yield(.measured(round: round, findings: found))
            host.note(found.isEmpty ? "round \(round): measured clean" : "round \(round): \(found.count) to fix — \(found[0].sentence)")
            if best == nil || found.count <= best!.findings.count { best = (drawn, rendered, found) }
            guard !found.isEmpty, round < rounds, let model else { break }
            host.note("revising the infographic")
            // A revision that changes nothing would draw the same page: the rounds end there.
            guard let revised = try? await askSheet(model, system: PlateSheetDraft.reviseSystem, user: PlateSheetDraft.revise(sheet, findings: found)),
                  !revised.blocks.isEmpty, revised != sheet else { break }
            sheet = revised
            yield(.revised(round: round))
        }
        guard let best else { throw PlateError.render("no round drew") }
        return try writeSheet(best.sheet, best.rendered, findings: best.findings, rounds: last, folder: folder)
    }

    private func askSheet(_ model: any AgentHostModel, system: String, user: String) async throws -> PlateSheet {
        let data = try await model.object(schema: PlateSheetDraft.schema, system: system, user: user, maxTokens: 4_000, seconds: 300)
        do {
            return try JSONDecoder().decode(PlateSheet.self, from: data)
        } catch {
            throw AgentHostError.answer("\(error)")
        }
    }

    /// The PNG, carrying the sheet it was drawn from, where `output` says or where a project keeps its pictures.
    private func writeSheet(_ sheet: PlateSheet, _ rendered: PlateRendered, findings: [PlateFinding], rounds: Int, folder: URL) throws -> PlateResult {
        let png = Self.output(input.output, folder: folder, title: sheet.title)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let json = (try? encoder.encode(sheet)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        do {
            try FileManager.default.createDirectory(at: png.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PlatePNG.embedding(json, in: rendered.png).write(to: png)
        } catch { throw PlateError.unwritable(png.path) }
        return PlateResult(path: png.path, paths: [png.path], width: rendered.width, height: rendered.height, rounds: rounds,
                           findings: findings.map(\.sentence), title: sheet.title, lanes: 0, nodes: 0, edges: 0,
                           form: PlateForm.infographic.rawValue, blocks: sheet.blocks.count)
    }
}
