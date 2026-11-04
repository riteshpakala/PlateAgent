import Foundation
import GraniteAgents
import XCTest
@testable import PlateAgent

/// The package as an app finds it: by its record, with the schema a model is shown and the guide a host prompts with.
final class PlateAgentTests: XCTestCase {
    func testTheRecordIsFoundWithNothingListed() throws {
        let plate = try XCTUnwrap(GraniteRoster.discovered().package("plate"), "the record is in this test binary")
        XCTAssertEqual(plate.module, "PlateAgent")
        XCTAssertEqual(plate.summary, PlateAgent.summary)
        XCTAssertEqual(plate.lanes, 1, "one WebKit page draws every plate")
    }

    func testTheSchemaIsWhatAModelIsShown() {
        let plate = AnyAgentPackage(PlateAgent.self)
        XCTAssertEqual(plate.schema, .object([
            .init(name: "brief", schema: .string, required: false),
            .init(name: "sources", schema: .array(.string), required: false),
            .init(name: "spec", schema: .string, required: false),
            .init(name: "output", schema: .string, required: false),
            .init(name: "rounds", schema: .integer, required: false),
            .init(name: "form", schema: .string, required: false),
            .init(name: "directory", schema: .string, required: false),
        ]))
        XCTAssertTrue(plate.takesDirectory)
        XCTAssertEqual(Set(plate.fields.keys), ["brief", "sources", "spec", "output", "rounds", "form"], "a note beside every field the model sees")
    }

    func testTheGuideSaysHowToAskForAPlate() {
        let guide = AnyAgentPackage(PlateAgent.self).guide
        for word in ["sources", "brief", "spec", "rounds", "path", "infographic", "architecture", "quotes"] { XCTAssertTrue(guide.contains(word), "the guide says \(word)") }
    }
}
