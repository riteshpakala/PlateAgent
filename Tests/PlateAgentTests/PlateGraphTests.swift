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
        try write("Sources/Agents/Services/TranscriptService/TranscriptService.swift", "struct TranscriptService {\n    @Agent(.merge) var coder: Coder.Agent\n    @Agent(.parallel(max: 4)) package var worker: Worker.Agent\n    static func open() {}\n}\n")
        try write("Sources/App/Services/ModelService/ModelService.swift", "//  WHAT: The one model: install, memory.\nstruct ModelService {}\n")
        try write("Sources/App/Services/ProjectService/ProjectService.swift", "struct ProjectService {}\n")
        try write("Sources/App/Services/ProjectService/Models/ProjectFacts/ProjectFacts.swift", "struct ProjectFacts {}\n")
        try write("Sources/Agents/Services/TranscriptService/TranscriptService+Center.swift", "extension TranscriptService {}\n")
        try write("Sources/Agents/Services/LoggerHelper/LoggerHelper.swift", "struct LoggerHelper {}\n")
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
        XCTAssertEqual(graph.parts.filter(\.beside).map(\.name), ["TranscriptService"],
                       "a service in another target the parts refer to joins them; a helper they never name does not")
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

    /// The front ends are read off the manifest and the roots: what a person runs, the root that holds the parts, the
    /// app's root that starts it and a service that root holds; and a part's operations in the order it declares its
    /// events, its wiring at boot last.
    func testTheFrontEndsAreReadOffTheManifestAndTheRoots() throws {
        let root = try Fixture.folder()
        func write(_ path: String, _ text: String) throws {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        try write("Package.swift", #"let package = Package(name: "Shop", products: [.executable(name: "shop", targets: ["ShopCLI"]), .executable(name: "ShopApp", targets: ["ShopApp"])])"# + "\n")
        try write("Sources/ShopCLI/ShopCommand.swift", #"@main struct ShopCommand { static let configuration = CommandConfiguration(commandName: "shop", abstract: "shop — a till in a terminal"); func run() { _ = ShopRoot.shared } }"# + "\n")
        try write("Sources/ShopCLI/Commands/ListCommand.swift", #"struct ListCommand { static let configuration = CommandConfiguration(abstract: "list the orders") }"# + "\n")
        try write("Sources/ShopApp/main.swift", "import AppKit\n\n// A windowed till: one window a register. AppKit owns the process.\nlet app = NSApplication.shared\n")
        try write("Sources/ShopApp/ShopAppRoot.swift", "final class ShopAppRoot {\n    let runtime = ShopRoot.shared\n    @Relay var theme: ThemeService\n    @Relay var orders: OrderService\n    @Relay var stock: StockService\n}\n")
        try write("Sources/ShopApp/Services/ThemeService/ThemeService.swift", "/// Light or dark, and the accent.\nstruct ThemeService {}\n")
        try write("Sources/ShopRuntime/Root/ShopRoot.swift", "final class ShopRoot {\n    static let shared = ShopRoot()\n    @Relay var orders: OrderService\n    @Relay var stock: StockService\n}\n")
        try write("Sources/ShopRuntime/Root/ShopRoot+Boot.swift", "extension ShopRoot {\n    func boot() { orders.center.connect.send(); stock.center.connect.send() }\n}\n")
        try write("Sources/ShopRuntime/Services/OrderService/OrderService.swift", "struct OrderService {\n    @Relay var stock: StockService\n}\n")
        try write("Sources/ShopRuntime/Services/OrderService/OrderService+Center.swift",
                  "extension OrderService {\n    struct Center {\n        @Event var set: Set.Reducer\n        @Event var connect: Connect.Reducer\n        @Event var place: Place.Reducer\n        @Event var cancel: Cancel.Reducer\n    }\n}\n")
        for op in ["Set", "Connect", "Place", "Cancel"] {
            try write("Sources/ShopRuntime/Services/OrderService/Reducers/OrderService.\(op).swift", "extension OrderService {}\n")
        }
        try write("Sources/ShopRuntime/Services/StockService/StockService.swift", "struct StockService {}\n")
        let graph = PlateGraph.read([root.appendingPathComponent("Sources/ShopRuntime/Services")], root: root)
        XCTAssertEqual(graph.parts.first { $0.name == "OrderService" }?.operations, ["Place", "Cancel", "Connect"],
                       "as the center declares them, `Set` never, the root's wiring last")
        XCTAssertEqual(graph.root, "ShopRoot", "both roots hold every part; the root is the one the app's root names")
        let front = graph.starters.filter { $0.role != .file || $0.name == graph.root || !$0.reaches.isEmpty }
        XCTAssertEqual(front.map(\.name), ["shop", "Shop.app", "ShopAppRoot", "ShopRoot", "ThemeService"].sorted { a, b in
            front.firstIndex { $0.name == a } ?? 0 < front.firstIndex { $0.name == b } ?? 0 })
        let shop = try XCTUnwrap(graph.starters.first { $0.name == "shop" })
        XCTAssertEqual(shop.what, "a till in a terminal", "the entry's own abstract, without its name")
        XCTAssertEqual(shop.reaches, ["ShopRoot"])
        XCTAssertEqual(shop.path, "Sources/ShopCLI")
        let app = try XCTUnwrap(graph.starters.first { $0.name == "Shop.app" })
        XCTAssertEqual(app.what, "A windowed till: one window a register", "an app is named for the package")
        XCTAssertEqual(app.reaches, ["ShopAppRoot"], "the app's root, which names the root")
        XCTAssertEqual(graph.starters.first { $0.name == "ShopAppRoot" }?.reaches, ["ShopRoot", "ThemeService"])
        XCTAssertEqual(graph.starters.first { $0.name == "ThemeService" }?.role, .held)
        let said = graph.render()
        XCTAssertTrue(said.contains("- shop · what a person runs · Sources/ShopCLI → ShopRoot\n  a till in a terminal"), said)
        XCTAssertTrue(said.contains("- ShopRoot · the root: it holds 2 of the 2 parts"), said)
        XCTAssertTrue(said.contains("- ThemeService · a service the front end holds"), said)
    }

    /// `CRAFT_ROOT=<a Craft checkout> swift test --filter PlateGraphTests/testCraftsServices` prints what a draft of
    /// Craft's services would be told.
    func testCraftsServices() throws {
        guard let path = ProcessInfo.processInfo.environment["CRAFT_ROOT"] else { throw XCTSkip("set CRAFT_ROOT to read a Craft checkout") }
        let root = URL(fileURLWithPath: path)
        let sources = [root.appendingPathComponent("Sources/CraftRuntime/Services")]
        let started = Date()
        let said = PlateGraph.read(sources, root: root).render()
        print(said)
        print("chars: \(said.count) in \(String(format: "%.2f", Date().timeIntervalSince(started))) s")
    }
}
