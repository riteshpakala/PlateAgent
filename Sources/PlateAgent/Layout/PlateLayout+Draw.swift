import Foundation

extension PlateLayout {
    /// The plate as a page: lanes, then boxes, then arrows over them, then numbers and labels over the arrows, the
    /// legend under the lanes, all inside the card, under the header.
    func page(_ spec: PlateSpec, faces: PlateKit.Faces) -> String {
        var canvas = PlateCanvas()
        for lane in lanes { canvas.lane(lane.box, lane.lane.colour, lane.lane.name, id: lane.lane.id, right: lane.labelRight) }
        for node in nodes {
            switch node.kind {
            case .service: canvas.node(node.box, node.colour, name: node.node.name, duty: node.node.duty, code: node.node.code, id: node.node.id)
            case .agent: canvas.agent(node.box, name: node.node.name, what: node.node.code ?? node.node.duty, id: node.node.id)
            case .external: canvas.ext(node.box, name: node.node.name, what: node.node.code ?? node.node.duty, id: node.node.id)
            }
        }
        for route in routes { canvas.curve(route.d, route.colour, heads: route.heads, dashed: route.dashed) }
        for route in routes {
            let edge = spec.edges[route.edge]
            if let mark = route.mark, let number = edge.number {
                canvas.mark(x: mark.x, y: mark.y, number, edge.style == .dashedGrey ? .dial : .gold, id: "mark:\(route.edge + 1)")
            }
            if let wire = route.wire, let text = edge.label { canvas.wire(wire, text, route.colour, id: "wire:\(route.edge + 1)") }
        }
        if let legend { canvas.note(legend, html: PlateHTML.legend(spec.legendText), size: PlateGeometry.legendSize) }
        let svgHeight = card.bottom + 110
        let body = PlateKit.card(card, heading: spec.headingText, machine: spec.machine?.trimmed.nonEmpty)
            + "\n<svg width=\"\(PlateHTML.n(PlatePalette.width))\" height=\"\(PlateHTML.n(svgHeight))\">" + canvas.svg.joined() + "</svg>\n"
            + canvas.labels.joined(separator: "\n")
        return PlateKit.page(caption: spec.caption.isEmpty ? "RAO STUDIOS" : spec.caption, title: spec.title, subtitle: spec.subtitle,
                             body: body, tag: spec.tag ?? "", height: height, faces: faces)
    }
}
