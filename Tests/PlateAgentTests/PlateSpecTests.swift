import Foundation
import XCTest
@testable import PlateAgent

/// What a spec may say, and what the model hears when it says too much or names what is not there.
final class PlateSpecTests: XCTestCase {
    func testTheFlowSpecChecksClean() {
        XCTAssertEqual(Fixture.flow.normalized().check(), [])
    }

    func testEachLimitIsAFindingTheModelCanActOn() {
        let rows: [(String, (inout PlateSpec) -> Void, PlateFinding.Kind, String)] = [
            ("a long duty", { $0.nodes[5].duty = String(repeating: "a", count: 131) }, .limit, "box session's duty is 131 characters and holds 110"),
            ("an arrow to nobody", { $0.edges[0].to = "nobody" }, .unknown, "arrow 1 names `nobody`"),
            ("a lane nobody declares", { $0.nodes[0].lane = "nowhere" }, .unknown, "box craft sits in lane `nowhere`"),
            ("seven lanes", { spec in for i in 0..<2 { spec.lanes.append(PlateLane(id: "x\(i)", name: "x\(i)", colour: .red)) } }, .limit, "7 lanes"),
            ("a gap in the walk", { $0.edges[1].number = 13 }, .limit, "number the walk 1 to 12"),
            ("a box under one in another lane", { $0.nodes[9].under = "records" }, .unknown, "sits in another lane"),
            ("a long title", { $0.title = "One turn through every service Craft has" }, .limit, "the title is 40 characters"),
        ]
        for (name, change, kind, words) in rows {
            var spec = Fixture.flow
            change(&spec)
            let found = spec.normalized().check()
            XCTAssertTrue(found.contains { $0.kind == kind && $0.sentence.contains(words) }, "\(name): \(found.map(\.sentence))")
        }
    }

    func testALooseDraftIsReadAndResolved() throws {
        let json = #"""
        {"title": "Loose", "subtitle": "s", "caption": "c",
         "lanes": [{"name": "The Web", "color": "grey"}, {"id": "api", "name": "the api", "colour": "purple", "beside": "yes"}],
         "nodes": [{"name": "Page", "lane": "The Web"}, {"id": "handler", "lane": "api", "name": "Handler", "kind": "llm", "column": "2"},
                   {"bad": true}],
         "edges": [{"from": "Page", "to": "handler", "number": "1", "style": "dashed-gold"}, {"from": "page"}]}
        """#
        let spec = try JSONDecoder().decode(PlateSpec.self, from: Data(json.utf8)).normalized()
        XCTAssertEqual(spec.lanes.map(\.id), ["the-web", "api"], "an id made from the name")
        XCTAssertEqual(spec.lanes.map(\.colour), [.dial, .violet], "colours named loosely")
        XCTAssertEqual(spec.lanes[1].beside, true)
        XCTAssertEqual(spec.nodes.first?.lane, "the-web", "a lane named by its name resolves to its id")
        XCTAssertEqual(spec.nodes[1].kind, .agent)
        XCTAssertEqual(spec.nodes[1].column, 2)
        XCTAssertEqual(spec.edges[0].from, "page", "an arrow that names a box by its name resolves")
        XCTAssertEqual(spec.edges[0].number, 1)
        XCTAssertEqual(spec.edges[0].style, .dashedGold)
        XCTAssertEqual(spec.check().filter { $0.kind == .unknown }.count, 1, "the arrow with no end is named, nothing else")
    }

    func testClampedAlwaysDraws() {
        var spec = Fixture.flow
        spec.edges.append(PlateEdge(from: "session", to: "nobody", number: 40))
        spec.nodes[0].name = String(repeating: "n", count: 60)
        let clamped = spec.clamped()
        XCTAssertFalse(clamped.edges.contains { $0.to == "nobody" })
        XCTAssertEqual(clamped.nodes[0].name.count, PlateLimits.name)
        XCTAssertEqual(clamped.edges.compactMap(\.number).sorted(), Array(1...12))
        XCTAssertEqual(clamped.check(), [], "what the last round draws checks clean")
    }
}
