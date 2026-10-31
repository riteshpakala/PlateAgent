import Foundation
import GraniteAgents
import XCTest
@testable import PlateAgent

/// The flow plate drawn from its spec, in WebKit, the way a host calls it: written at 2x, measured clean.
@MainActor
final class PlateRendererTests: XCTestCase {
    func testTheFlowSpecDrawsLikeTheFlowPlate() async throws {
        let folder = try Fixture.folder()
        let spec = try Fixture.write(Fixture.flow, to: folder)
        let input = #"{"spec": "\#(spec.path)", "output": "flow.png", "directory": "\#(folder.path)"}"#
        let answer = try await AnyAgentPackage(PlateAgent.self).perform(Data(input.utf8))
        let result = try JSONDecoder().decode(PlateResult.self, from: answer)
        if let out = ProcessInfo.processInfo.environment["PLATE_OUT"] {
            try? FileManager.default.removeItem(atPath: out)
            try FileManager.default.copyItem(atPath: result.path, toPath: out)
        }
        print("plate:", result.width, "x", result.height, "findings:", result.findings)
        XCTAssertEqual(result.width, 3200, "twice the page's 1600")
        XCTAssertEqual(Double(result.height), 3142, accuracy: 3142 * 0.12, "about as tall as flow.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
        XCTAssertEqual(result.paths.map { URL(fileURLWithPath: $0).lastPathComponent }, ["flow.png", "flow.plate.json"])
        XCTAssertEqual(result.findings, [], "the flow plate measures clean")
    }
}
