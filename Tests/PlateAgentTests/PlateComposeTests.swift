import Foundation
import GraniteAgents
import XCTest
@testable import PlateAgent

/// A plan and the code's graph make the plate: parts with their operations and agents, starters as front ends, the
/// walk numbered, the code's other references drawn and labelled with what one part calls on the other.
@MainActor
final class PlateComposeTests: XCTestCase {
    private let graph: PlateGraph = {
        var graph = PlateGraph()
        graph.parts = [PlateGraph.Part(name: "SessionService", path: "Sources/App/Services/SessionService", what: "Opens a session and runs its turns. More.",
                                       operations: ["Open", "Send", "Close"], rank: 1),
                       PlateGraph.Part(name: "TranscriptService", path: "Sources/Agents/Services/TranscriptService", what: "Every transcript",
                                       operations: ["Apply", "Open"], agents: ["coder (Coder)", "worker (Worker)"], beside: true),
                       PlateGraph.Part(name: "ModelService", path: "Sources/App/Services/ModelService", what: "The one model", operations: ["Use"])]
        graph.references = [PlateGraph.Reference(from: "SessionService", to: "TranscriptService", count: 16, example: "", calls: ["apply", "transcript", "Open"]),
                            PlateGraph.Reference(from: "SessionService", to: "ModelService", count: 3, example: "", calls: ["use"])]
        graph.starters = [PlateGraph.Starter(name: "AppRoot", path: "Sources/App/Root/AppRoot.swift", parts: ["ModelService", "SessionService"],
                                             what: "Boots the services")]
        return graph
    }()

    func testAPlanAndTheGraphMakeThePlate() {
        let plan = PlatePlan(caption: "RAO STUDIOS · APP · THE FLOW", title: "One turn, every service", subtitle: "s",
                             lanes: [.init(id: "root", name: "the root", colour: .dial, boxes: ["AppRoot"]),
                                     .init(id: "turn", name: "a turn", colour: .blue, boxes: ["Session", "TranscriptService", "ModelService", "Nowhere"])],
                             duties: ["ModelService": "the one model: install, memory"],
                             walk: [.init(from: "AppRoot", to: "Session"), .init(from: "SessionService", to: "TranscriptService"),
                                    .init(from: "TranscriptService", to: "worker", label: "perform"), .init(from: "Nowhere", to: "Ghost")],
                             externals: [.init(name: "MLX", under: "ModelService", what: "through Frigate")])
        let spec = PlateCompose.spec(plan, graph: graph)
        XCTAssertEqual(spec.nodes.map(\.name), ["AppRoot", "SessionService", "TranscriptService", "coder", "worker", "ModelService", "Nowhere", "MLX"],
                       "a shortened name resolves; agents hang under their part; an unknown box is drawn as written")
        let session = spec.node("sessionservice")
        XCTAssertEqual(session?.duty, "Opens a session and runs its turns", "the code's own line, its first sentence")
        XCTAssertEqual(session?.code, "Open · Send · Close")
        XCTAssertEqual(spec.node("modelservice")?.duty, "the one model: install, memory", "the plan's duty wins")
        XCTAssertEqual(spec.node("approot")?.code, "App/Root")
        XCTAssertEqual(spec.node("worker")?.under, "transcriptservice")
        XCTAssertEqual(spec.node("mlx")?.kind, .external)
        let edges = spec.edges.map { "\($0.from)→\($0.to) \($0.number.map(String.init) ?? "-") \($0.label ?? "") \($0.style?.rawValue ?? "solid")" }
        XCTAssertEqual(edges, ["approot→sessionservice 1  solid",
                               "sessionservice→transcriptservice 2 apply · open solid",
                               "transcriptservice→worker 3 perform dashedGold",
                               "transcriptservice→coder -  dashedGold",
                               "modelservice→mlx -  dashedGrey",
                               "sessionservice→modelservice - use solid"])
        XCTAssertEqual(spec.normalized().check().filter { $0.kind == .unknown }, [], "every arrow is between boxes it drew")
    }

    /// `CRAFT_ROOT=<a Craft checkout> PLATE_OUT=<png>` draws Craft's services from a plan like the one a model should write.
    func testCraftsFlowFromAPlan() async throws {
        guard let path = ProcessInfo.processInfo.environment["CRAFT_ROOT"] else { throw XCTSkip("set CRAFT_ROOT to read a Craft checkout") }
        let root = URL(fileURLWithPath: path)
        let graph = PlateGraph.read([root.appendingPathComponent("Sources/CraftRuntime/Services")], root: root)
        let plan = try JSONDecoder().decode(PlatePlan.self, from: Data(#"""
        {"caption":"RAO STUDIOS · CRAFT · THE FLOW","title":"One turn, every service","subtitle":"from the ask to the records: what each service is responsible for, in the order a turn passes through it","heading":"A turn, through the services","machine":"ONE ASK, END TO END","tag":"every box is a service or an agent in Sources/CraftAgents, Sources/CraftRuntime and Sources/CraftApp",
         "lanes":[{"id":"front","name":"the front ends","colour":"dial","boxes":["CraftAppRoot","Cockpit","Settings"]},
                  {"id":"root","name":"the root","colour":"dial","boxes":["CraftRuntimeRoot"],"note":"{dial:the handlers:} memory held » halt the turns · critical pressure » stop the workers"},
                  {"id":"turn","name":"a turn","colour":"blue","boxes":["SessionService","TranscriptService","ModelService"]},
                  {"id":"project","name":"the project","colour":"green","boxes":["RecordsService","ProjectService","WatchService","ThreadService"]},
                  {"id":"machine","name":"the machine","colour":"orange","beside":true,"boxes":["StacksService","ConfigService","UpdateService","AccountService"]}],
         "duties":{"SessionService":"opens a session, performs its turn, then reads the facts and counts the recall","TranscriptService":"the transcript, modes and attention of every open session","ModelService":"the one model: catalog, install, memory, the ceiling, pressure"},
         "walk":[{"from":"CraftAppRoot","to":"CraftRuntimeRoot","label":"boot · open · turn"},{"from":"CraftRuntimeRoot","to":"SessionService"},{"from":"SessionService","to":"TranscriptService"},{"from":"TranscriptService","to":"worker","label":"perform"},{"from":"worker","to":"MLX","label":"generate"},{"from":"SessionService","to":"RecordsService"},{"from":"SessionService","to":"ProjectService"},{"from":"SessionService","to":"WatchService"},{"from":"WatchService","to":"ThreadService","label":"files"}],
         "externals":[{"name":"MLX","under":"ModelService","what":"through Frigate"},{"name":"Thread, in AII","under":"ThreadService","what":"the index every Rao app shares"},{"name":"Sewn, in AII","under":"AccountService","what":"sign-in and the account's tokens"}],
         "legend":"Each box is a **GraniteService**; its line says what it is responsible for. Solid arrows are dispatches down the relay graph; {gold:dashed gold} is an agent's run and what it writes; dashed grey is a process across a wire. The numbers walk one turn."}
        """#.utf8))
        let spec = PlateCompose.spec(plan, graph: graph)
        let folder = try Fixture.folder()
        let specURL = try Fixture.write(spec, to: folder, name: "composed.plate.json")
        let answer = try await AnyAgentPackage(PlateAgent.self).perform(Data(#"{"spec": "\#(specURL.path)", "output": "composed.png", "directory": "\#(folder.path)"}"#.utf8))
        let result = try JSONDecoder().decode(PlateResult.self, from: answer)
        if let out = ProcessInfo.processInfo.environment["PLATE_OUT"] {
            try? FileManager.default.removeItem(atPath: out)
            try FileManager.default.copyItem(atPath: result.path, toPath: out)
        }
        print("composed:", spec.nodes.count, "boxes", spec.edges.count, "arrows · findings:", result.findings)
    }
}
