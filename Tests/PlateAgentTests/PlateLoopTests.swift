import Foundation
import GraniteAgents
import XCTest
@testable import PlateAgent

/// A call from the ask to the PNG, the host's model scripted: drafted, drawn, measured, fixed, written.
@MainActor
final class PlateLoopTests: XCTestCase {
    private func json(_ spec: PlateSpec) throws -> Data { try JSONEncoder().encode(spec) }

    func testADraftThatOverflowsIsFixedByTheModel() async throws {
        let folder = try Fixture.folder()
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Sources/App"), withIntermediateDirectories: true)
        try "// WHAT: the session service.\nstruct SessionService {}\n".write(to: folder.appendingPathComponent("Sources/App/SessionService.swift"),
                                                                              atomically: true, encoding: .utf8)
        var long = Fixture.flow
        long.nodes[5].code = "Open · Send · Spawn · Control · Close · Halt · Check · Recall"
        let model = FakeHostModel([try json(long), try json(Fixture.flow)])
        let notes = NoteBox()
        let host = AgentHost(directory: folder.path, ask: "a graphic of the flow $plate", model: model, note: { notes.append($0) })
        let input = #"{"sources": ["Sources/App"], "brief": "the turn, through the services", "directory": "\#(folder.path)"}"#
        let answer = try await AnyAgentPackage(PlateAgent.self).perform(Data(input.utf8), host: host)
        let result = try JSONDecoder().decode(PlateResult.self, from: answer)
        XCTAssertEqual(result.rounds, 2, "the first draft overflowed; the second measured clean")
        XCTAssertEqual(result.findings, [])
        XCTAssertEqual(result.paths.map { URL(fileURLWithPath: $0).lastPathComponent }, ["one-turn-every-service.png", "one-turn-every-service.plate.json"],
                       "named for the title, in the folder: the project has no pictures folder")
        XCTAssertTrue(result.paths.allSatisfy { FileManager.default.fileExists(atPath: $0) })
        let asked = model.asked
        XCTAssertEqual(asked.count, 2)
        XCTAssertTrue(asked[0].user.contains("a graphic of the flow $plate"), "the draft hears the person's ask")
        XCTAssertTrue(asked[0].user.contains("Sources/App/SessionService.swift"), "and the sources' digest")
        XCTAssertTrue(asked[0].system.contains("ATELIER"), "with the example of another system")
        XCTAssertTrue(asked[1].user.contains("box session's code line"), "the revision hears what the plate found: \(asked[1].user.suffix(400))")
        XCTAssertTrue(notes.lines.contains { $0.hasPrefix("drafting") })
        XCTAssertTrue(notes.lines.contains { $0.hasPrefix("round 2: measured clean") }, "\(notes.lines)")
    }

    func testWithoutAModelOrASpecItSaysWhy() async {
        do {
            _ = try await AnyAgentPackage(PlateAgent.self).perform(Data(#"{"brief": "the flow"}"#.utf8))
            XCTFail("a plate was drafted with no model")
        } catch {
            XCTAssertTrue("\(error)".contains("host's model"), "\(error)")
        }
    }

    func testASpecDrawsAgainWithNoModel() async throws {
        let folder = try Fixture.folder()
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("docs/README_Assets"), withIntermediateDirectories: true)
        let spec = try Fixture.write(Fixture.flow, to: folder)
        let answer = try await AnyAgentPackage(PlateAgent.self).perform(Data(#"{"spec": "\#(spec.path)", "directory": "\#(folder.path)"}"#.utf8))
        let result = try JSONDecoder().decode(PlateResult.self, from: answer)
        XCTAssertTrue(result.path.hasSuffix("docs/README_Assets/one-turn-every-service.png"), "the project's pictures folder, when it has one")
        XCTAssertEqual(result.rounds, 1)
    }
}
