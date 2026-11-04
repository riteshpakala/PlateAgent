import Foundation
import GraniteAgents
import XCTest
@testable import PlateAgent

/// An infographic plate: read loosely off a model's JSON, held to what a plate holds, drawn block by block in the
/// plate style, chosen when the call is not a project's architecture, and drafted, drawn, fixed and written end to end.
@MainActor
final class PlateSheetTests: XCTestCase {
    /// Lines written for the plate: a quote with no `by` is one, and the legend says so.
    static let quotes = PlateSheet(
        caption: "RAO STUDIOS · THE STUDIO · THE WORDS", title: "Small steps, long roads",
        subtitle: "five lines to keep beside the desk: on starting, on keeping on, and on finishing",
        heading: "Words to work by", machine: "ONE LINE A DAY", legend: "The lines were written for this plate; **gold** marks the day's one.",
        columns: 2,
        blocks: [
            PlateBlock(kind: .quote, text: "Begin before you feel ready; ready is a place you reach by walking.", colour: .gold, span: 2),
            PlateBlock(kind: .quote, text: "A small thing done today outweighs a large thing planned for someday.", colour: .dial),
            PlateBlock(kind: .quote, text: "Keep the promise you made to the morning.", colour: .dial),
            PlateBlock(kind: .flow, title: "How a day goes well", items: ["one line", "one hour", "one thing finished"], colour: .gold),
            PlateBlock(kind: .drawing, title: "A sun over the hill",
                       paths: ["M10 80 Q50 50 90 80", "M50 30 m-12 0 a12 12 0 1 0 24 0 a12 12 0 1 0 -24 0", "M50 10 L50 16", "M28 18 L32 23", "M72 18 L68 23"],
                       colour: .orange),
        ])

    private func json(_ sheet: PlateSheet) throws -> Data { try JSONEncoder().encode(sheet) }

    func testASheetIsReadLooselyOffAModelsJSON() throws {
        let text = #"""
        {"caption": "RAO STUDIOS · X · THE Y", "title": "One line", "subtitle": "a thesis", "columns": "2",
         "blocks": [{"kind": "Quotation", "text": "Stay curious.", "by": " — Seneca", "colour": "yellow", "span": "2"},
                    {"kind": "process", "title": "A path", "items": "first\nsecond\n\nthird"},
                    {"kind": "metric", "figure": 42, "title": "the answer"},
                    {"kind": "nonsense", "title": "a note", "text": "  "}]}
        """#
        let sheet = try JSONDecoder().decode(PlateSheet.self, from: Data(text.utf8))
        XCTAssertEqual(sheet.columns, 2)
        XCTAssertEqual(sheet.blocks.map(\.kind), [.quote, .flow, .stat, .card], "a kind named loosely; an unknown one is a card")
        XCTAssertEqual(sheet.blocks[0].by, "Seneca", "the kit draws the dash")
        XCTAssertEqual(sheet.blocks[0].colour, .gold)
        XCTAssertEqual(sheet.blocks[0].span, 2)
        XCTAssertEqual(sheet.blocks[1].items, ["first", "second", "third"], "a list written as lines")
        XCTAssertEqual(sheet.blocks[2].figure, "42", "a figure written as a number")
        XCTAssertNil(sheet.blocks[3].text, "only spaces is no text")
        XCTAssertTrue(PlateSheet.isSheet(Data(text.utf8)))
        XCTAssertTrue(PlateSheet.isSheet(try json(Self.quotes)), "it says its form")
        XCTAssertFalse(PlateSheet.isSheet(try JSONEncoder().encode(Fixture.flow)), "a flow plate is not one")
    }

    func testASheetIsHeldToWhatAPlateHoldsAndClampedToIt() {
        XCTAssertEqual(Self.quotes.check(), [], "the fixture holds")
        var long = Self.quotes
        long.title = String(repeating: "word ", count: 10)
        long.blocks[3].items = ["one"]
        long.blocks[4].paths = ["<script>alert(1)</script>"]
        long.blocks += Array(repeating: PlateBlock(kind: .stat, title: "x"), count: 10)
        let sentences = long.check().map(\.sentence)
        XCTAssertTrue(sentences.contains { $0.hasPrefix("the title is 50 characters") }, "\(sentences)")
        XCTAssertTrue(sentences.contains { $0.contains("needs two or more `items`") })
        XCTAssertTrue(sentences.contains { $0.contains("no stroke the kit can draw") })
        XCTAssertTrue(sentences.contains { $0.contains("has no `figure`") })
        XCTAssertTrue(sentences.contains { $0.contains("15 blocks") })
        let clamped = long.clamped()
        XCTAssertEqual(clamped.blocks.count, PlateSheet.Limits.blocks)
        XCTAssertLessThanOrEqual(clamped.title.count, PlateSheet.Limits.title)
        XCTAssertEqual(clamped.blocks[4].paths, [], "nothing but path data reaches the page")
        XCTAssertEqual(PlateSheet.strokes(["M10 10 L90 90", "javascript:x", "L10 10", "M0 0 C 10,20 30,40 50 60 Z"]),
                       ["M10 10 L90 90", "M0 0 C 10,20 30,40 50 60 Z"], "a stroke starts with a move and holds only path data")
    }

    func testTheKitDrawsEveryKindInThePlateStyle() throws {
        var sheet = Self.quotes
        sheet.blocks += [PlateBlock(kind: .steps, title: "<b>Start</b>", items: ["one", "two"]), PlateBlock(kind: .list, title: "Keep", items: ["a", "b"]),
                         PlateBlock(kind: .stat, title: "lines", figure: "5"), PlateBlock(kind: .card, title: "Why", text: "Because.")]
        let faces = try PlateResources.faces()
        let html = PlateSheetKit.page(sheet, faces: faces)
        for n in 1...sheet.blocks.count { XCTAssertTrue(html.contains("data-id=\"block:\(n)\""), "block \(n) is drawn") }
        for kind in PlateBlock.Kind.allCases { XCTAssertTrue(html.contains("k-\(kind.rawValue)"), "a \(kind) is drawn as one") }
        XCTAssertTrue(html.contains("&lt;b&gt;Start&lt;/b&gt;"), "a block's words are escaped")
        XCTAssertTrue(html.contains("grid-template-columns: repeat(2"), "on the columns asked for")
        XCTAssertTrue(html.contains("grid-column: span 2"), "a block that spans")
        // No row is left part empty: the block before a gap, and the last, widen to the row's end.
        let rows: [([Int?], Int, [Int])] = [
            ([nil, nil, nil], 2, [1, 1, 2]),
            ([nil, 2, nil], 2, [2, 2, 2]),
            ([1, 1, 2, 1, 1], 2, [1, 1, 2, 1, 1]),
            ([nil, nil, 2, nil], 3, [1, 2, 2, 1]),
            ([nil, 3, nil, nil], 3, [3, 3, 1, 2]),
            ([5], 2, [2]),
            ([], 2, []),
        ]
        for (asked, columns, drawn) in rows {
            XCTAssertEqual(PlateSheetKit.spans(asked.map { PlateBlock(kind: .card, span: $0) }, columns: columns), drawn, "\(asked) on \(columns)")
        }
        XCTAssertTrue(html.contains("window.__plate.after"), "the page fits its blocks")
        XCTAssertTrue(html.contains("Small steps, long roads"))
    }

    func testAQuoteCreditsOnlyASpeakerThePersonNamed() {
        let grounds = "quotes by Seneca and lao tzu, on patience"
        let rows: [(String, Bool)] = [
            ("Seneca", true), ("Lao Tzu", true), ("— Seneca", true),
            ("Maya Angelou", false), ("W. E. Dusin", false), ("Ezra", false), ("W. E.", false), ("Patience Smith", false),
        ]
        for (by, named) in rows { XCTAssertEqual(PlateSheet.named(by, in: grounds), named, by) }
        var sheet = Self.quotes
        sheet.blocks[0].by = "Maya Angelou"
        sheet.blocks[1].by = "Seneca"
        sheet.blocks[3].by = "Ezra"
        let found = sheet.speakers(named: grounds)
        XCTAssertEqual(found.map(\.element), ["block:1"], "a speaker the person did not name; a flow has no speaker")
        XCTAssertTrue(found[0].sentence.contains("the quote by Maya Angelou"), found[0].sentence)
        let drawn = sheet.attributed(to: grounds)
        XCTAssertEqual(drawn.blocks.map(\.by), [nil, "Seneca", nil, "Ezra", nil], "only a quote's speaker is the person's to name")
    }

    func testAnUnnamedSpeakerIsLeftOffThePlate() async throws {
        var credited = Self.quotes
        credited.blocks[0].by = "Maya Angelou"
        let rows: [(ask: String?, brief: String, kept: String?)] = [
            ("Generate some inspirational quotes on a $plate", "inspirational quotes", nil),
            ("Generate some inspirational quotes on a $plate", "quotes, one by Maya Angelou", nil),  // the calling model's words
            ("Put a few lines by Maya Angelou on a $plate", "quotes on courage", "Maya Angelou"),
            (nil, "quotes, one by Maya Angelou", "Maya Angelou"),  // a call with no ask: the brief is the request
        ]
        for (ask, brief, kept) in rows {
            let folder = try Fixture.folder()
            let host = AgentHost(directory: folder.path, ask: ask, model: FakeHostModel([try json(credited)]))
            let answer = try await AnyAgentPackage(PlateAgent.self).perform(
                Data(#"{"form": "infographic", "brief": "\#(brief)", "rounds": 1, "directory": "\#(folder.path)"}"#.utf8), host: host)
            let result = try JSONDecoder().decode(PlateResult.self, from: answer)
            let carried = try XCTUnwrap(PlatePNG.embedded(in: Data(contentsOf: URL(fileURLWithPath: result.path))))
            let sheet = try JSONDecoder().decode(PlateSheet.self, from: Data(carried.utf8))
            XCTAssertEqual(sheet.blocks[0].by, kept, brief)
            XCTAssertEqual(result.findings.contains { $0.contains("credits a speaker") }, kept == nil, "\(brief): \(result.findings)")
        }
    }

    func testALongTitleIsDrawnWholeAndSmaller() async throws {
        var long = Self.quotes
        long.title = "Growth needs patience, not power, to last"
        let folder = try Fixture.folder()
        let model = FakeHostModel([try json(long)])
        let result = try JSONDecoder().decode(PlateResult.self, from: try await AnyAgentPackage(PlateAgent.self).perform(
            Data(#"{"form": "infographic", "brief": "quotes", "directory": "\#(folder.path)"}"#.utf8), host: AgentHost(directory: folder.path, model: model)))
        XCTAssertEqual(result.findings, [], "41 characters fit, drawn smaller")
        XCTAssertEqual(result.title, long.title, "whole, never cut")
        XCTAssertNil(result.note, "a clean plate needs no word to its caller")
        XCTAssertEqual(model.asked.count, 1)
    }

    func testARevisionThatChangesNothingEndsTheRoundsAndTheAnswerSaysItIsDone() async throws {
        var long = Self.quotes
        long.title = String(repeating: "patience ", count: 6)
        let folder = try Fixture.folder()
        let model = FakeHostModel([try json(long), try json(long), try json(long)])
        let result = try JSONDecoder().decode(PlateResult.self, from: try await AnyAgentPackage(PlateAgent.self).perform(
            Data(#"{"form": "infographic", "brief": "quotes", "directory": "\#(folder.path)"}"#.utf8), host: AgentHost(directory: folder.path, model: model)))
        XCTAssertEqual(model.asked.count, 2, "the draft and one revision, which answered the same spec")
        XCTAssertEqual(result.rounds, 1)
        XCTAssertFalse(result.findings.isEmpty)
        XCTAssertTrue(result.note?.contains("this call is done") == true, "\(result.note ?? "")")
    }

    func testTheFormIsTheCallsElseTheCodesElseAnInfographic() {
        XCTAssertEqual(PlateForm.chosen("infographic", graph: nil), .infographic)
        XCTAssertEqual(PlateForm.chosen("quotes", graph: nil), .infographic)
        XCTAssertEqual(PlateForm.chosen("flow", graph: nil), .architecture, "a form named wins over the code")
        XCTAssertEqual(PlateForm.chosen(nil, graph: nil), .infographic, "no code graph: an infographic")
        XCTAssertNil(PlateForm(loose: "banana"))
    }

    func testTheExamplesWordsAreToldApart() {
        var copied = Self.quotes
        copied.title = "One starter, every loaf"
        copied.blocks[0].text = "Wild yeast and lactic bacteria living in flour and water, fed each day."
        let found = PlateSheetDraft.echoes(copied).map(\.element)
        XCTAssertEqual(found, ["title", "block:1"])
        XCTAssertEqual(PlateSheetDraft.echoes(Self.quotes), [])
    }

    func testAnInfographicIsDraftedDrawnFixedAndWritten() async throws {
        let folder = try Fixture.folder()
        var long = Self.quotes
        long.title = "Small steps, long roads, and the patient work"
        let model = FakeHostModel([try json(long), try json(Self.quotes)])
        let notes = NoteBox()
        let host = AgentHost(directory: folder.path, ask: "Generate some inspirational quotes on a $plate", model: model, note: { notes.append($0) })
        let input = #"{"form": "infographic", "brief": "inspirational quotes on starting and finishing", "directory": "\#(folder.path)"}"#
        let answer = try await AnyAgentPackage(PlateAgent.self).perform(Data(input.utf8), host: host)
        let result = try JSONDecoder().decode(PlateResult.self, from: answer)
        if let out = ProcessInfo.processInfo.environment["PLATE_SHEET_OUT"] {
            try? FileManager.default.removeItem(atPath: out)
            try FileManager.default.copyItem(atPath: result.path, toPath: out)
        }
        print("sheet:", result.width, "x", result.height, "findings:", result.findings)
        XCTAssertEqual(result.form, "infographic")
        XCTAssertEqual(result.blocks, 5)
        XCTAssertEqual(result.rounds, 2, "the first draft's title ran long; the second measured clean")
        XCTAssertEqual(result.findings, [])
        XCTAssertEqual(result.width, 3200, "twice the page's 1600")
        XCTAssertGreaterThan(result.height, 1600, "the header and the card")
        XCTAssertLessThan(Double(result.height) / 2, PlateMeasure.sheetTallest, "one picture")
        XCTAssertEqual(URL(fileURLWithPath: result.path).lastPathComponent, "small-steps-long-roads.png")
        let carried = try XCTUnwrap(PlatePNG.embedded(in: Data(contentsOf: URL(fileURLWithPath: result.path))))
        XCTAssertTrue(PlateSheet.isSheet(Data(carried.utf8)), "the PNG carries the sheet it was drawn from")
        let asked = model.asked
        XCTAssertEqual(asked.count, 2)
        XCTAssertTrue(asked[0].system.contains("BAKERY"), "the example is another subject's")
        XCTAssertTrue(asked[0].user.contains("inspirational quotes on starting"), "the draft hears the brief")
        XCTAssertTrue(asked[0].user.contains("$plate"), "and the person's ask")
        XCTAssertTrue(asked[1].user.contains("the title is"), "the revision hears what the plate found: \(asked[1].user.suffix(300))")
        XCTAssertTrue(notes.lines.contains { $0.hasPrefix("drafting an infographic") }, "\(notes.lines)")

        // Drawn again from its PNG, with no model at all.
        let again = try JSONDecoder().decode(PlateResult.self, from: await AnyAgentPackage(PlateAgent.self).perform(
            Data(#"{"spec": "\#(result.path)", "output": "again.png", "directory": "\#(folder.path)"}"#.utf8)))
        XCTAssertEqual(again.form, "infographic")
        XCTAssertEqual(again.title, "Small steps, long roads")
        XCTAssertEqual(again.rounds, 1)
    }

    func testAPlateWithNoSourcesIsAnInfographic() async throws {
        let folder = try Fixture.folder()
        let model = FakeHostModel([try json(Self.quotes)])
        let answer = try await AnyAgentPackage(PlateAgent.self).perform(
            Data(#"{"brief": "three lines on patience", "directory": "\#(folder.path)"}"#.utf8), host: AgentHost(directory: folder.path, model: model))
        let result = try JSONDecoder().decode(PlateResult.self, from: answer)
        XCTAssertEqual(result.form, "infographic", "nothing of the code to draw")
        XCTAssertTrue(model.asked.first?.system.contains("infographic plate") == true)
    }
}
