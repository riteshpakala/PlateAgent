import Foundation
import XCTest
@testable import PlateAgent

/// The code's own graph, which the model draws from: parts by the folder named for their type, their operations and
/// agents, who refers to whom, ranked by depth, and what starts them from outside.
final class PlateGraphTests: XCTestCase {
    private func project() throws -> URL {
        let root = try Fixture.folder()
        func write(_ path: String, _ text: String) throws {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        try write("Sources/App/Services/SessionService/SessionService.swift",
                  "import Granite\nimport Engine\n/// Opens a session and runs its turns. More.\nstruct SessionService {\n    @Relay var models: ModelService\n}\n")
        try write("Sources/App/Services/SessionService/Reducers/SessionService.Send.swift", "extension SessionService {\n    // ModelService is named in a comment\n    func send() { models.center.load.send() ; TranscriptService.open() }\n}\n")
        try write("Sources/App/Services/SessionService/Reducers/SessionService.Open.swift", "extension SessionService {}\n")
        try write("Sources/App/Services/TranscriptService/TranscriptService.swift", "struct TranscriptService {\n    @Agent(.merge) var coder: Coder.Agent\n    @Agent(.parallel(max: 4)) package var worker: Worker.Agent\n    static func open() {}\n}\n")
        try write("Sources/App/Services/ModelService/ModelService.swift", "//  WHAT: The one model: install, memory.\nstruct ModelService {}\n")
        try write("Sources/App/Services/ProjectService/ProjectService.swift", "struct ProjectService {}\n")
        try write("Sources/App/Services/ProjectService/Models/ProjectFacts/ProjectFacts.swift", "struct ProjectFacts {}\n")
        try write("scripts/plates.py", "class Canvas:\n    s = 'SessionService ModelService'\n")
        try write("Sources/App/Root/AppRoot.swift", "final class AppRoot {\n    let sessions = SessionService()\n    let models = ModelService()\n}\n")
        try write("Tests/AppTests/RootTests.swift", "final class RootTests { let s = SessionService(); let m = ModelService() }\n")
        return root
    }

    func testTheGraphIsReadOffTheCode() throws {
        let root = try project()
        let graph = PlateGraph.read([root.appendingPathComponent("Sources/App/Services")], root: root)
        XCTAssertEqual(graph.parts.map(\.name), ["ModelService", "ProjectService", "SessionService", "TranscriptService"],
                       "a model's folder inside a service is the service's")
        let session = try XCTUnwrap(graph.parts.first { $0.name == "SessionService" })
        XCTAssertEqual(session.path, "Sources/App/Services/SessionService")
        XCTAssertEqual(session.operations, ["Open", "Send"], "a reducer file is an operation")
        XCTAssertEqual(session.what, "Opens a session and runs its turns")
        XCTAssertEqual(session.rank, 1)
        XCTAssertEqual(graph.parts.first { $0.name == "TranscriptService" }?.agents, ["coder (Coder)", "worker (Worker)"])
        XCTAssertEqual(graph.parts.first { $0.name == "ModelService" }?.what, "The one model: install, memory")
        XCTAssertEqual(graph.references.map { "\($0.from)→\($0.to)" }.sorted(), ["SessionService→ModelService", "SessionService→TranscriptService"])
        XCTAssertEqual(graph.references.first { $0.to == "ModelService" }?.count, 1, "a comment does not count")
        XCTAssertEqual(graph.starters.map(\.name), ["AppRoot"], "what starts them, in their language, and never a test")
        XCTAssertEqual(graph.imports.map(\.name), ["Engine", "Granite"])
        let said = graph.render()
        XCTAssertTrue(said.contains("- SessionService · Sources/App/Services/SessionService · rank 1 · operations: Open · Send"), said)
        XCTAssertTrue(said.contains("- AppRoot (Sources/App/Root/AppRoot.swift) → ModelService, SessionService"), said)
    }

    /// `CRAFT_ROOT=<a Craft checkout> swift test --filter PlateGraphTests/testCraftsServices` prints what a draft of
    /// Craft's services would be told.
    func testCraftsServices() throws {
        guard let path = ProcessInfo.processInfo.environment["CRAFT_ROOT"] else { throw XCTSkip("set CRAFT_ROOT to read a Craft checkout") }
        let root = URL(fileURLWithPath: path)
        let sources = ["Sources/CraftRuntime/Services", "Sources/CraftAgents/Services", "Sources/CraftApp/Services"].map { root.appendingPathComponent($0) }
        let started = Date()
        let said = PlateGraph.read(sources, root: root).render()
        print(said)
        print("chars: \(said.count) in \(String(format: "%.2f", Date().timeIntervalSince(started))) s")
    }
}
