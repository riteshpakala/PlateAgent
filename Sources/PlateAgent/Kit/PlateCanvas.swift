import Foundation

/// The marks a plate draws with, the Rao plates' `Canvas`: lanes, boxes, agents, externals, arrows, numbered
/// steps and labels. SVG for the strokes, absolutely placed HTML for the words; every placed element says what it
/// is (`data-id`) so the measure pass can name it.
struct PlateCanvas {
    private(set) var svg: [String] = []
    private(set) var labels: [String] = []
    private let n = PlateHTML.n
    private let esc = PlateHTML.escape

    mutating func lane(_ box: PlateBox, _ colour: PlateColour, _ name: String, id: String, right: Bool) {
        svg.append("<rect x=\"\(n(box.x))\" y=\"\(n(box.y))\" width=\"\(n(box.w))\" height=\"\(n(box.h))\" rx=\"16\" fill=\"\(colour.hex)\" fill-opacity=\".045\" stroke=\"\(colour.hex)\" stroke-opacity=\".28\"/>")
        let top = box.bottom - 30
        let side = right ? "right:\(n(PlatePalette.width - box.right + 18))px" : "left:\(n(box.x + 18))px"
        labels.append("<div class=\"lanelab\" data-id=\"lane:\(esc(id))\" style=\"\(side); top:\(n(top))px; color:\(colour.hex)\">\(esc(name.uppercased()))</div>")
    }

    mutating func node(_ box: PlateBox, _ colour: PlateColour, name: String, duty: String?, code: String?, id: String) {
        svg.append("<rect x=\"\(n(box.x))\" y=\"\(n(box.y))\" width=\"\(n(box.w))\" height=\"\(n(box.h))\" rx=\"11\" fill=\"#ffffff\" fill-opacity=\".03\" stroke=\"rgba(255,255,255,.16)\"/>"
                   + "<rect x=\"\(n(box.x))\" y=\"\(n(box.y + 10))\" width=\"5\" height=\"\(n(max(box.h - 20, 4)))\" rx=\"2.5\" fill=\"\(colour.hex)\"/>")
        labels.append("<div class=\"node\" data-id=\"node:\(esc(id))\" style=\"left:\(n(box.x))px; top:\(n(box.y))px; width:\(n(box.w))px; height:\(n(box.h))px\">"
                      + Self.nodeInner(name: name, duty: duty, code: code) + "</div>")
    }

    mutating func agent(_ box: PlateBox, name: String, what: String?, id: String) {
        svg.append("<rect x=\"\(n(box.x))\" y=\"\(n(box.y))\" width=\"\(n(box.w))\" height=\"\(n(box.h))\" rx=\"9\" fill=\"\(PlateColour.gold.hex)\" fill-opacity=\".06\" stroke=\"\(PlateColour.gold.hex)\" stroke-opacity=\".75\" stroke-dasharray=\"5 4\"/>")
        labels.append("<div class=\"agt\" data-id=\"node:\(esc(id))\" style=\"left:\(n(box.x))px; top:\(n(box.y))px; width:\(n(box.w))px; height:\(n(box.h))px\">"
                      + Self.agentInner(name: name, what: what) + "</div>")
    }

    mutating func ext(_ box: PlateBox, name: String, what: String?, id: String) {
        svg.append("<rect x=\"\(n(box.x))\" y=\"\(n(box.y))\" width=\"\(n(box.w))\" height=\"\(n(box.h))\" rx=\"10\" fill=\"#ffffff\" fill-opacity=\"0\" stroke=\"rgba(255,255,255,.3)\" stroke-dasharray=\"6 5\"/>")
        labels.append("<div class=\"ext\" data-id=\"node:\(esc(id))\" style=\"left:\(n(box.x))px; top:\(n(box.y))px; width:\(n(box.w))px; height:\(n(box.h))px\">"
                      + Self.extInner(name: name, what: what) + "</div>")
    }

    /// An arrow along `d`, with a head at its end and, for `both`, at its start.
    mutating func curve(_ d: String, _ colour: PlateColour, heads: [PlateRoute.Head], dashed: Bool, width: Double = 1.8) {
        let dash = dashed ? " stroke-dasharray=\"6 5\"" : ""
        svg.append("<path d=\"\(d)\" fill=\"none\" stroke=\"\(colour.hex)\" stroke-width=\"\(n(width))\"\(dash) stroke-linecap=\"round\"/>")
        for head in heads { svg.append(arrowhead(head, colour)) }
    }

    /// A mono label with a dark pill under it, so it reads over a stroke.
    mutating func wire(_ box: PlateBox, _ text: String, _ colour: PlateColour, id: String) {
        labels.append("<div class=\"wire svcw\" data-id=\"\(id)\" style=\"left:\(n(box.x))px; top:\(n(box.y))px; color:\(colour.hex)\">\(esc(text))</div>")
    }

    /// A numbered step on a path.
    mutating func mark(x: Double, y: Double, _ number: Int, _ colour: PlateColour, id: String) {
        svg.append("<circle cx=\"\(n(x))\" cy=\"\(n(y))\" r=\"11\" fill=\"#1a1a17\" stroke=\"\(colour.hex)\" stroke-width=\"1.6\"/>")
        labels.append("<div class=\"wire\" data-id=\"\(id)\" style=\"left:\(n(x - 11))px; top:\(n(y - 9))px; width:22px; text-align:center; color:\(colour.hex); "
                      + "font-family:\(PlatePalette.sans); font-weight:600; font-size:12px\">\(number)</div>")
    }

    mutating func note(_ box: PlateBox, html: String, size: Double = 15, id: String = "legend") {
        labels.append("<div class=\"note\" data-id=\"\(esc(id))\" style=\"left:\(n(box.x))px; top:\(n(box.y))px; width:\(n(box.w))px; font-size:\(n(size))px; line-height:1.4\">\(html)</div>")
    }

    func arrowhead(_ head: PlateRoute.Head, _ colour: PlateColour) -> String {
        let (x, y) = (head.x, head.y)
        let d: String
        switch head.direction {
        case .down: d = "M\(n(x - 7)),\(n(y - 9)) L\(n(x)),\(n(y)) L\(n(x + 7)),\(n(y - 9))"
        case .up: d = "M\(n(x - 7)),\(n(y + 9)) L\(n(x)),\(n(y)) L\(n(x + 7)),\(n(y + 9))"
        case .right: d = "M\(n(x - 9)),\(n(y - 7)) L\(n(x)),\(n(y)) L\(n(x - 9)),\(n(y + 7))"
        case .left: d = "M\(n(x + 9)),\(n(y - 7)) L\(n(x)),\(n(y)) L\(n(x + 9)),\(n(y + 7))"
        }
        return "<path d=\"\(d)\" fill=\"none\" stroke=\"\(colour.hex)\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
    }

    // MARK: What a box says, shared with the measure pass so it measures what the plate draws.

    static func nodeInner(name: String, duty: String?, code: String?) -> String {
        "<b>\(PlateHTML.escape(name))</b>" + (duty.map { "<span>\(PlateHTML.escape($0))</span>" } ?? "")
            + (code.map { "<code>\(PlateHTML.escape($0))</code>" } ?? "")
    }

    static func agentInner(name: String, what: String?) -> String {
        "<b>\(PlateHTML.escape(name))</b>" + (what.map { "<span>\(PlateHTML.escape($0))</span>" } ?? "")
    }

    static func extInner(name: String, what: String?) -> String {
        "<b>\(PlateHTML.escape(name))</b>" + (what.map { "<span>\(PlateHTML.escape($0))</span>" } ?? "")
    }
}
