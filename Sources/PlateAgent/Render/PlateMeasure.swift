import Foundation

/// What WebKit is asked about a plate, and what its answers mean.
///
/// Before the layout, `heights`: each box said at the width the grid gives it, and the legend at its width, so the
/// layout places boxes as tall as what they say. After the plate is settled, `findings`: every text wider than its
/// box, every two things drawn over each other, everything past the page's edge, and how wide the title and the
/// subtitle came out. The model reads them as sentences, one each.
enum PlateMeasure {
    /// What `findingsScript` answers.
    struct Raw: Codable, Sendable, Equatable {
        struct Overflow: Codable, Sendable, Equatable { let id: String; let part: String; let scroll: Double; let client: Double }
        struct Overlap: Codable, Sendable, Equatable { let a: String; let b: String; let w: Double; let h: Double }
        struct Outside: Codable, Sendable, Equatable { let id: String; let x: Double; let right: Double }
        var overflow: [Overflow]
        var overlaps: [Overlap]
        var outside: [Outside]
        var title: Double
        var subtitle: Double
    }

    /// The page the heights are measured on: every box at its width, the legend at its width.
    static func page(_ spec: PlateSpec, grid: PlateGrid, faces: PlateKit.Faces) -> String {
        let n = PlateHTML.n, esc = PlateHTML.escape
        var boxes: [String] = []
        for node in spec.nodes {
            let width = grid.cells[node.id]?.width ?? 300
            let id = "node:\(esc(node.id))"
            switch node.kind ?? .service {
            case .service:
                boxes.append("<div class=\"node m\" data-id=\"\(id)\" style=\"width:\(n(width))px\">"
                             + PlateCanvas.nodeInner(name: node.name, duty: node.duty, code: node.code) + "</div>")
            case .agent:
                boxes.append("<div class=\"agt m\" data-id=\"\(id)\" style=\"width:\(n(width))px\">"
                             + PlateCanvas.agentInner(name: node.name, what: node.code ?? node.duty) + "</div>")
            case .external:
                boxes.append("<div class=\"ext m\" data-id=\"\(id)\" style=\"width:\(n(width))px\">"
                             + PlateCanvas.extInner(name: node.name, what: node.code ?? node.duty) + "</div>")
            }
        }
        boxes.append("<div class=\"note m\" data-id=\"legend\" style=\"width:\(n(PlateGeometry.legendW))px; font-size:\(n(PlateGeometry.legendSize))px; line-height:1.4\">"
                     + PlateHTML.legend(spec.legendText) + "</div>")
        return PlateKit.measurePage(boxes: boxes.joined(separator: "\n"), faces: faces)
    }

    static let heightsScript = """
    await document.fonts.ready;
    const out = {};
    for (const el of document.querySelectorAll('[data-id]')) out[el.dataset.id] = el.getBoundingClientRect().height;
    return JSON.stringify(out);
    """

    /// The heights the page answered, as the layout reads them.
    static func measures(_ json: String) -> PlateMeasures {
        let raw = (try? JSONDecoder().decode([String: Double].self, from: Data(json.utf8))) ?? [:]
        var heights: [String: Double] = [:]
        for (key, value) in raw where key.hasPrefix("node:") { heights[String(key.dropFirst(5))] = value }
        return PlateMeasures(heights: heights, legend: raw["legend"] ?? 0)
    }

    static let findingsScript = """
    const rect = (el) => { const r = el.getBoundingClientRect(); return {x: r.left, y: r.top, w: r.width, h: r.height}; };
    const overflow = [];
    for (const el of document.querySelectorAll('.node, .agt, .ext')) {
      const cs = getComputedStyle(el);
      const inner = el.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
      for (const child of el.children) {
        const wide = Math.max(child.scrollWidth, child.getBoundingClientRect().width);
        if (wide > inner + 1) overflow.push({id: el.dataset.id, part: child.tagName.toLowerCase(), scroll: Math.round(wide), client: Math.round(inner)});
      }
      if (el.scrollHeight > el.clientHeight + 2) overflow.push({id: el.dataset.id, part: 'height', scroll: el.scrollHeight, client: el.clientHeight});
    }
    const placed = [...document.querySelectorAll('[data-id]')].filter((el) => /^(node|wire|mark|lane|lanenote):|^legend$/.test(el.dataset.id))
      .map((el) => ({id: el.dataset.id, ...rect(el)}));
    const overlaps = [];
    for (let i = 0; i < placed.length; i++) for (let j = i + 1; j < placed.length; j++) {
      const a = placed[i], b = placed[j];
      const ka = a.id.split(':'), kb = b.id.split(':');
      if (/^(wire|mark)$/.test(ka[0]) && /^(wire|mark)$/.test(kb[0]) && ka[1] === kb[1]) continue;
      const w = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x), h = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
      if (w > 2 && h > 2) overlaps.push({a: a.id, b: b.id, w: Math.round(w), h: Math.round(h)});
    }
    const width = document.documentElement.clientWidth || 1600;
    const outside = placed.filter((p) => p.x < -1 || p.x + p.w > 1600 + 1).map((p) => ({id: p.id, x: Math.round(p.x), right: Math.round(p.x + p.w)}));
    const ink = (selector) => { const el = document.querySelector(selector); if (!el) return 0; const range = document.createRange(); range.selectNodeContents(el); return Math.round(range.getBoundingClientRect().right); };
    return JSON.stringify({overflow, overlaps, outside, title: ink('.title'), subtitle: ink('.sub')});
    """

    /// What the measure found, one sentence each, naming the spec's boxes and arrows by what the model wrote.
    static func findings(_ raw: Raw, spec: PlateSpec) -> [PlateFinding] {
        var found: [PlateFinding] = []
        for item in raw.overflow {
            let name = describe(item.id, spec)
            let element = item.id
            switch item.part {
            case "code":
                let fits = Int(item.client / (11.5 * PlatePalette.monoAdvance))
                found.append(PlateFinding(.overflow, element, numbers: [Int(item.scroll), Int(item.client)],
                                          "\(name): its code line is \(Int(item.scroll)) px wide in a box of \(Int(item.client)): shorten `code` to about \(fits) characters."))
            case "b":
                let fits = Int(item.client / 9.5)
                found.append(PlateFinding(.overflow, element, numbers: [Int(item.scroll), Int(item.client)],
                                          "\(name): its name is \(Int(item.scroll)) px wide in a box of \(Int(item.client)): shorten `name` to about \(fits) characters."))
            case "height":
                found.append(PlateFinding(.overflow, element, numbers: [Int(item.scroll), Int(item.client)],
                                          "\(name) says more than its box holds: shorten its `duty`."))
            default:
                let fits = Int(item.client / (11 * PlatePalette.monoAdvance))
                found.append(PlateFinding(.overflow, element, numbers: [Int(item.scroll), Int(item.client)],
                                          "\(name): its line is \(Int(item.scroll)) px wide in a box of \(Int(item.client)): say it in about \(fits) characters."))
            }
        }
        for item in raw.overlaps {
            found.append(PlateFinding(.overlap, item.a, numbers: [Int(item.w), Int(item.h)],
                                      "\(describe(item.a, spec)) is drawn over \(describe(item.b, spec)) (\(Int(item.w))×\(Int(item.h)) px): "
                                          + "shorten or drop the label, or move one of the boxes to another column."))
        }
        for item in raw.outside {
            found.append(PlateFinding(.outside, item.id, numbers: [Int(item.x), Int(item.right)],
                                      "\(describe(item.id, spec)) runs past the plate's edge: shorten it."))
        }
        let edge = PlatePalette.width - PlateGeometry.cardX
        if raw.title > edge {
            found.append(PlateFinding(.overflow, "title", numbers: [Int(raw.title), Int(edge)],
                                      "the title runs to \(Int(raw.title)) px and the plate ends at \(Int(edge)): keep it under about \(PlateLimits.title - 4) characters."))
        }
        if raw.subtitle > edge {
            found.append(PlateFinding(.overflow, "subtitle", numbers: [Int(raw.subtitle), Int(edge)],
                                      "the subtitle runs to \(Int(raw.subtitle)) px and the plate ends at \(Int(edge)): say it in about \(Int(Double(spec.subtitle.count) * edge / raw.subtitle) - 4) characters."))
        }
        return found
    }

    /// An element of the page, said as the model wrote it.
    static func describe(_ id: String, _ spec: PlateSpec) -> String {
        let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return id == "legend" ? "the legend" : id }
        switch parts[0] {
        case "node": return "box \(spec.node(parts[1])?.name ?? parts[1])"
        case "lane": return "the name of lane \(parts[1])"
        case "lanenote": return "the note of lane \(parts[1])"
        case "wire", "mark":
            guard let index = Int(parts[1]), spec.edges.indices.contains(index - 1) else { return id }
            let edge = spec.edges[index - 1]
            let ends = "\(spec.node(edge.from)?.name ?? edge.from) → \(spec.node(edge.to)?.name ?? edge.to)"
            return parts[0] == "wire" ? "the label `\(edge.label ?? "")` on arrow \(index) (\(ends))" : "the number on arrow \(index) (\(ends))"
        default: return id
        }
    }
}
