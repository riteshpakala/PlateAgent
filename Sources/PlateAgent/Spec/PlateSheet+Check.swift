import Foundation

/// What one infographic plate holds, what a sheet that goes past it is told, and the sheet clamped so a PNG is still
/// written. The header's limits are the flow plate's (`PlateLimits`), but for the title: the kit draws a long one
/// smaller to fit (`PlateSheetKit.titleFloor`), so it holds what fits at its smallest.
extension PlateSheet {
    enum Limits {
        /// About 31 px a character at 70% of the title's 104 px: 44 fill the plate.
        static let title = 44
        static let blocks = 12
        static let items = 8
        static let item = 90
        static let quote = 240
        static let text = 280
        static let blockTitle = 48
        static let by = 60
        static let figure = 12
        static let paths = 16
        static let path = 900
    }

    /// Every way the sheet goes past what a plate holds, one sentence each.
    func check() -> [PlateFinding] {
        var found: [PlateFinding] = []
        func over(_ element: String, _ text: String?, _ limit: Int, _ what: String) {
            guard let text, text.count > limit else { return }
            found.append(PlateFinding(.limit, element, numbers: [text.count, limit], "\(what) is \(text.count) characters: say it in at most \(limit)."))
        }
        over("caption", caption, PlateLimits.caption, "the caption")
        over("title", title, Limits.title, "the title")
        over("subtitle", subtitle, PlateLimits.subtitle, "the subtitle")
        over("heading", heading, PlateLimits.heading, "the heading")
        over("legend", legend, PlateLimits.legend, "the legend")
        over("tag", tag, PlateLimits.tag, "the tag")
        if title.isEmpty { found.append(PlateFinding(.limit, "title", "the plate has no title: give it a short editorial sentence.")) }
        if blocks.isEmpty { found.append(PlateFinding(.limit, "blocks", "the plate has no blocks: say what it shows in two to nine.")) }
        if blocks.count > Limits.blocks {
            found.append(PlateFinding(.limit, "blocks", numbers: [blocks.count, Limits.blocks],
                                      "the plate holds \(blocks.count) blocks and reads as one picture with at most \(Limits.blocks): merge or drop some."))
        }
        for (index, block) in blocks.enumerated() {
            let element = "block:\(index + 1)", name = Self.describe(index, block)
            over(element, block.title, Limits.blockTitle, "\(name)'s title")
            over(element, block.text, block.kind == .quote ? Limits.quote : Limits.text, "\(name)'s text")
            over(element, block.by, Limits.by, "who said \(name)")
            over(element, block.figure, Limits.figure, "\(name)'s figure")
            if block.items.count > Limits.items {
                found.append(PlateFinding(.limit, element, numbers: [block.items.count, Limits.items],
                                          "\(name) has \(block.items.count) lines: keep the \(Limits.items) that matter most."))
            }
            for item in block.items { over(element, item, Limits.item, "a line of \(name)") }
            switch block.kind {
            case .quote where block.text == nil, .card where block.text == nil && block.title == nil:
                found.append(PlateFinding(.limit, element, "\(name) says nothing: give it its `text`."))
            case .steps where block.items.count < 2, .list where block.items.count < 2, .flow where block.items.count < 2:
                found.append(PlateFinding(.limit, element, "\(name) needs two or more `items`."))
            case .stat where block.figure == nil:
                found.append(PlateFinding(.limit, element, "\(name) has no `figure`: give it the number it shows."))
            case .drawing where Self.strokes(block.paths).isEmpty:
                found.append(PlateFinding(.limit, element, "\(name) has no stroke the kit can draw: write `paths` as SVG path data (M, L, C, Q, A, Z) on a 100 × 100 square."))
            default: break
            }
            if block.kind == .drawing, block.paths.count > Limits.paths {
                found.append(PlateFinding(.limit, element, numbers: [block.paths.count, Limits.paths],
                                          "\(name) has \(block.paths.count) strokes: draw it in at most \(Limits.paths)."))
            }
        }
        return found
    }

    /// The sheet cut to what a plate holds: a model that went past a limit still gets its plate.
    func clamped() -> PlateSheet {
        var sheet = self
        func cut(_ text: String?, _ limit: Int) -> String? { text.map { $0.count > limit ? String($0.prefix(limit - 1)) + "…" : $0 } }
        sheet.caption = cut(caption, PlateLimits.caption) ?? ""
        sheet.title = cut(title, Limits.title) ?? ""
        sheet.subtitle = cut(subtitle, PlateLimits.subtitle) ?? ""
        sheet.heading = cut(heading, PlateLimits.heading)
        sheet.legend = cut(legend, PlateLimits.legend)
        sheet.tag = cut(tag, PlateLimits.tag)
        sheet.blocks = blocks.prefix(Limits.blocks).map { block in
            var block = block
            block.title = cut(block.title, Limits.blockTitle)
            block.text = cut(block.text, block.kind == .quote ? Limits.quote : Limits.text)
            block.by = cut(block.by, Limits.by)
            block.figure = cut(block.figure, Limits.figure)
            block.items = block.items.prefix(Limits.items).map { cut($0, Limits.item) ?? $0 }
            block.paths = Self.strokes(block.paths)
            block.span = block.span.map { min(max($0, 1), 3) }
            return block
        }
        return sheet
    }

    /// The strokes a drawing may carry: SVG path data and nothing else (letters of path commands, numbers, spaces,
    /// commas), each at most `Limits.path` characters, at most `Limits.paths` of them.
    ///
    /// PIN: NOTHING BUT PATH DATA reaches the page. A stroke is placed in a `d` attribute the kit writes; one that
    /// holds anything else is dropped, never escaped and drawn.
    static func strokes(_ paths: [String]) -> [String] {
        let allowed = Set("MmLlHhVvCcSsQqTtAaZz0123456789.,-+eE \n\t")
        return paths.prefix(Limits.paths).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= Limits.path && $0.allSatisfy(allowed.contains) && $0.first.map { "Mm".contains($0) } == true }
    }

    /// A block, said as the model wrote it: "block 3 (the quote by Seneca)".
    static func describe(_ index: Int, _ block: PlateBlock) -> String {
        let what: String
        switch block.kind {
        case .quote: what = block.by.map { "the quote by \($0)" } ?? "the quote"
        case .stat: what = "the stat " + (block.figure ?? block.title ?? "")
        default: what = block.title.map { "the \(block.kind.rawValue) “\($0)”" } ?? "the \(block.kind.rawValue)"
        }
        return "block \(index + 1) (\(what.trimmingCharacters(in: .whitespaces)))"
    }
}
