import Foundation
import XCTest
@testable import PlateAgent

/// Where the flow plate's parts go, without WebKit: the measures reckoned, the geometry held to what a plate needs.
final class PlateLayoutTests: XCTestCase {
    private func layout() -> (PlateSpec, PlateLayout) {
        let spec = Fixture.flow.clamped()
        let grid = PlateGrid.make(spec)
        return (spec, PlateLayout.make(spec, grid: grid, measures: .estimated(spec, grid: grid)))
    }

    func testTheLanesStackAndTwoSitSideBySide() {
        let (_, layout) = layout()
        let boxes = layout.lanes.map(\.box)
        XCTAssertEqual(layout.lanes.map(\.lane.id), ["front", "root", "turn", "project", "machine"])
        for (above, below) in zip(boxes.prefix(3), boxes.dropFirst().prefix(3)) { XCTAssertLessThan(above.bottom, below.y, "in the order they flow") }
        XCTAssertEqual(boxes[3].y, boxes[4].y, "the machine sits beside the project")
        XCTAssertLessThan(boxes[3].right, boxes[4].x)
        XCTAssertFalse(layout.lanes[3].labelRight, "the left of a pair says its name at its left foot")
    }

    func testNoTwoBoxesMeetAndEachSitsInItsLane() {
        let (_, layout) = layout()
        for (i, a) in layout.nodes.enumerated() {
            for b in layout.nodes.dropFirst(i + 1) { XCTAssertEqual(a.box.overlap(b.box), 0, "\(a.node.id) and \(b.node.id)") }
            let lane = layout.lanes.first { $0.lane.id == a.node.lane }!.box
            XCTAssertTrue(a.box.x >= lane.x && a.box.right <= lane.right && a.box.y >= lane.y && a.box.bottom <= lane.bottom, "\(a.node.id) in its lane")
        }
        let transcript = layout.nodes.first { $0.node.id == "transcript" }!.box
        for agent in ["coder", "worker"] {
            let box = layout.nodes.first { $0.node.id == agent }!.box
            XCTAssertGreaterThan(box.y, transcript.bottom, "\(agent) hangs under the box that runs it")
            XCTAssertTrue(box.x >= transcript.x && box.right <= transcript.right)
        }
    }

    func testEveryArrowRunsFromItsBoxToItsBoxThroughNoOther() {
        let (spec, layout) = layout()
        XCTAssertEqual(layout.routes.count, spec.edges.count)
        for route in layout.routes {
            let edge = spec.edges[route.edge]
            let from = layout.nodes.first { $0.node.id == edge.from }!.box, to = layout.nodes.first { $0.node.id == edge.to }!.box
            XCTAssertTrue(from.inset(1).contains(route.start) || from.inset(0.5).overlap(PlateBox(x: route.start.x - 0.5, y: route.start.y - 0.5, w: 1, h: 1)) > 0,
                          "arrow \(route.edge + 1) leaves \(edge.from)")
            XCTAssertTrue(to.inset(3).contains(route.end), "arrow \(route.edge + 1) arrives at \(edge.to)")
            XCTAssertEqual(route.crossings, [], "arrow \(route.edge + 1) crosses nothing")
        }
        XCTAssertEqual(layout.findings, [])
        XCTAssertEqual(layout.routes.filter { $0.mark != nil }.count, 12, "the twelve numbers of the walk are placed")
    }

    func testTheCardHoldsEverything() {
        let (_, layout) = layout()
        for box in layout.nodes.map(\.box) + layout.lanes.map(\.box) + [layout.legend!] {
            XCTAssertTrue(box.x >= layout.card.x && box.right <= layout.card.right && box.bottom <= layout.card.bottom)
        }
        XCTAssertEqual(layout.height, layout.card.bottom + PlateGeometry.pageFoot)
    }

    func testTheSameSpecDrawsTheSamePlate() throws {
        let (spec, first) = layout()
        let (_, second) = layout()
        let faces = PlateKit.Faces(font: "data:,", mark: "data:,")
        XCTAssertEqual(first.page(spec, faces: faces), second.page(spec, faces: faces))
    }
}
