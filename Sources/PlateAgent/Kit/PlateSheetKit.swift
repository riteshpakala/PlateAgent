import Foundation

/// An infographic plate as a page: the plates' header and foot (`PlateKit.page`), and under them one card holding the
/// blocks on a grid, each drawn as its kind is in the plates' style: a quote large in the face with a gold mark, a
/// figure in the title's silver, steps on gold rings, a flow's stops joined by arrows, a drawing in strokes.
///
/// PIN: THE PAGE FITS ITS BLOCKS. A flow plate's height is the layout's; a sheet's is what its blocks take, so the
/// page is drawn tall and, once settled, ends under the card (`window.__plate.after`), the tag at its foot.
enum PlateSheetKit {
    /// The page drawn before it is settled: tall enough for any sheet, cut to the card once it is.
    static let drawnHeight = 4800.0

    static func page(_ sheet: PlateSheet, faces: PlateKit.Faces) -> String {
        PlateKit.page(caption: sheet.caption, title: sheet.title, subtitle: sheet.subtitle,
                      body: style + body(sheet) + script, tag: sheet.tag ?? "", height: drawnHeight, faces: faces)
    }

    /// The card, its head, the grid and the closing line.
    static func body(_ sheet: PlateSheet) -> String {
        let esc = PlateHTML.escape, columns = sheet.grid
        var html = "<div class=\"sheet\" data-id=\"sheet\">"
        if let heading = sheet.heading {
            let right = sheet.machine.map { "<span class=\"machine\">\(esc($0.uppercased()))</span>" } ?? ""
            html += "<div class=\"head shead\"><span><i class=\"dot\" style=\"background:\(PlateColour.gold.hex)\"></i><b>\(esc(heading))</b></span>\(right)</div>"
        }
        html += "<div class=\"grid\" style=\"grid-template-columns: repeat(\(columns), minmax(0, 1fr))\">"
        let spans = self.spans(sheet.blocks, columns: columns)
        for (index, block) in sheet.blocks.enumerated() {
            html += self.block(block, index: index, span: spans[index])
        }
        html += "</div>"
        if let legend = sheet.legend { html += "<div class=\"slegend\" data-id=\"legend\">\(PlateHTML.legend(legend))</div>" }
        return html + "</div>"
    }

    /// The columns each block takes, so that no row is left part empty: a block that will not fit in what is left of
    /// its row starts the next, and the block before it widens to the row's end, as the last block does to the last.
    static func spans(_ blocks: [PlateBlock], columns: Int) -> [Int] {
        var spans = blocks.map { min(max($0.span ?? 1, 1), columns) }
        var used = 0
        for index in spans.indices {
            if used + spans[index] > columns {
                spans[index - 1] += columns - used
                used = 0
            }
            used = (used + spans[index]) % columns
        }
        if used > 0, !spans.isEmpty { spans[spans.count - 1] += columns - used }
        return spans
    }

    /// One block, as its kind is drawn, over `span` columns.
    static func block(_ block: PlateBlock, index: Int, span: Int) -> String {
        let esc = PlateHTML.escape
        let colour = (block.colour ?? defaultColour(block.kind)).hex
        var inner = ""
        let title = block.title.map { "<div class=\"bt\">\(esc($0))</div>" } ?? ""
        switch block.kind {
        case .quote:
            let words = (block.text ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\"“”‘’' \n"))
            inner = "<div class=\"q\"><i class=\"mk\">“</i>\(esc(words))<i class=\"mk\">”</i></div>"
                + (block.by.map { "<div class=\"by\">— \(esc($0))</div>" } ?? "")
        case .card:
            inner = title + (block.text.map { "<div class=\"bx\">\(esc($0))</div>" } ?? "")
        case .steps:
            inner = title + "<ol class=\"st\">" + block.items.enumerated().map { n, item in
                "<li><span class=\"step\">\(n + 1)</span><span>\(esc(item))</span></li>"
            }.joined() + "</ol>"
        case .list:
            inner = title + "<ul class=\"li\">" + block.items.map { "<li>\(esc($0))</li>" }.joined() + "</ul>"
        case .stat:
            inner = "<div class=\"fig\">\(esc(block.figure ?? ""))</div>" + (block.title.map { "<div class=\"bx\">\(esc($0))</div>" } ?? "")
                + (block.text.map { "<div class=\"bx dim\">\(esc($0))</div>" } ?? "")
        case .flow:
            inner = title + "<div class=\"fl\">" + block.items.map { "<span class=\"stop\">\(esc($0))</span>" }
                .joined(separator: "<span class=\"arr\">→</span>") + "</div>"
        case .drawing:
            let strokes = PlateSheet.strokes(block.paths).map {
                "<path d=\"\($0)\" fill=\"none\" stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" vector-effect=\"non-scaling-stroke\"/>"
            }.joined()
            inner = "<svg viewBox=\"0 0 100 100\" preserveAspectRatio=\"xMidYMid meet\">\(strokes)</svg>"
                + (block.title.map { "<div class=\"bt cap\">\(esc($0))</div>" } ?? "")
                + (block.text.map { "<div class=\"bx cap\">\(esc($0))</div>" } ?? "")
        }
        return "<div class=\"blk k-\(block.kind.rawValue)\" data-id=\"block:\(index + 1)\" style=\"grid-column: span \(span); --c: \(colour)\">\(inner)</div>"
    }

    /// The colour a kind takes when the model names none: a quote and a stat gold, the rest the plate's first blue.
    static func defaultColour(_ kind: PlateBlock.Kind) -> PlateColour {
        switch kind {
        case .quote, .stat, .flow: return .gold
        case .drawing: return .line
        case .card, .steps, .list: return .blue
        }
    }

    /// The blocks as the plates style them. A block's lines sit in the middle of its cell: a row is as tall as its
    /// tallest block, and a short one beside it would otherwise end in an empty card.
    static let style = """
    <style>
    .sheet { position: absolute; left: \(PlateHTML.n(PlateGeometry.cardX))px; top: 330px; width: \(PlateHTML.n(PlateGeometry.cardW))px; box-sizing: border-box;
             border: 1px solid rgba(255,255,255,.11); border-radius: 14px; background: rgba(255,255,255,.028); padding: 22px 26px 28px; }
    .shead { margin: 0 4px 22px; }
    .grid { display: grid; gap: 22px; align-items: stretch; }
    .blk { position: relative; box-sizing: border-box; min-width: 0; border-radius: 12px; background: rgba(255,255,255,.03);
           border: 1px solid rgba(255,255,255,.075); padding: 26px 30px 28px 34px; overflow-wrap: anywhere;
           display: flex; flex-direction: column; justify-content: center; }
    .blk::before { content: ""; position: absolute; left: 0; top: 20px; bottom: 20px; width: 3px; border-radius: 2px; background: var(--c); }
    .bt { font-size: 25px; line-height: 1.2; color: #ecebe5; margin-bottom: 12px; }
    .bx { font-size: 19px; line-height: 1.5; color: #a29f97; }
    .bx.dim { font-size: 16px; color: #8b8a84; margin-top: 8px; }
    .q { font-size: 34px; line-height: 1.3; color: #ecebe5; }
    .q .mk { color: var(--c); font-style: italic; padding: 0 .06em; }
    .k-quote .by { margin-top: 18px; font-size: 13px; letter-spacing: .22em; color: #8b8a84; text-transform: uppercase; }
    .fig { font-size: 78px; line-height: 1; font-weight: 500; padding-bottom: 10px;
           background: linear-gradient(100deg, #8d9097 0%, #c8cad0 35%, #f2f3f6 58%, #b6b9c1 100%); -webkit-background-clip: text; background-clip: text; color: transparent; }
    ol.st, ul.li { list-style: none; margin: 0; padding: 0; }
    ol.st li { display: flex; gap: 12px; align-items: baseline; font-size: 19px; line-height: 1.45; color: #a29f97; margin-top: 10px; }
    ol.st .step { border-color: var(--c); color: var(--c); }
    ul.li li { position: relative; padding-left: 22px; font-size: 19px; line-height: 1.45; color: #a29f97; margin-top: 8px; }
    ul.li li::before { content: ""; position: absolute; left: 3px; top: .64em; width: 7px; height: 7px; border-radius: 50%; background: var(--c); }
    .fl { display: flex; flex-wrap: wrap; align-items: center; gap: 12px 12px; }
    .fl .stop { border: 1px solid rgba(255,255,255,.16); border-radius: 999px; padding: 8px 18px; font-size: 19px; color: #ecebe5; background: rgba(255,255,255,.03); }
    .fl .arr { color: var(--c); font-family: \(PlatePalette.sans); font-style: normal; font-size: 20px; }
    .k-drawing svg { position: static; display: block; width: 100%; height: 220px; stroke: var(--c); }
    .cap { text-align: center; margin: 14px 0 0; }
    .slegend { margin: 24px 6px 0; font-size: 18px; line-height: 1.4; color: #a29f97; }
    .slegend b { font-weight: 400; color: #ecebe5; }
    </style>
    """

    /// The header fitted before it is placed: a title or subtitle wider than the plate is drawn smaller, down to
    /// `titleFloor` and `subtitleFloor` of its size, whole. Then the page cut to the card once it is settled, the
    /// tag at its foot.
    ///
    /// PIN: THE KIT FITS THE TITLE, THE MODEL DOES NOT CUT IT. A local model asked to shorten a title often answers
    /// the same spec; a title cut to "…" says less than the one it wrote. So the whole title is drawn, smaller.
    static let script = """
    <script>
    window.__plate = window.__plate || {};
    window.__plate.before = () => {
      const ctx = document.createElement("canvas").getContext("2d"), room = \(PlateHTML.n(PlatePalette.width - PlateGeometry.cardX - PlatePalette.ink - 8));
      for (const [selector, floor] of [[".title", \(titleFloor)], [".sub", \(subtitleFloor)]]) {
        const el = document.querySelector(selector), cs = getComputedStyle(el), size = parseFloat(cs.fontSize);
        ctx.font = `italic ${cs.fontWeight} ${size}px Playfair`;
        const width = ctx.measureText(el.textContent.trim()).width;
        if (width > room) el.style.fontSize = Math.max(size * floor, Math.floor(size * room / width)) + "px";
      }
    };
    window.__plate.after = () => {
      const sheet = document.querySelector(".sheet");
      const height = Math.ceil(sheet.getBoundingClientRect().bottom + \(PlateHTML.n(footRoom)));
      document.documentElement.style.height = document.body.style.height = height + "px";
      const tag = document.querySelector(".tag");
      if (tag) { tag.style.translate = "0 0"; tag.style.top = (height - 52) + "px"; }
      document.body.dataset.height = height;
      return height;
    };
    </script>
    """

    /// Under the card: room for the tag, as the flow plate leaves it.
    static let footRoom = 104.0

    /// The smallest a title or subtitle is drawn to fit, as a share of its size: what `PlateSheet.Limits.title`
    /// is counted at.
    static let titleFloor = 0.7
    static let subtitleFloor = 0.8
}
