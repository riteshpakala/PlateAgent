import Foundation

/// What the model is told for an infographic plate: how a good one reads, a worked example on another subject to copy
/// the shape of, and the keys. Then what to draw, what to change, or what to fix.
///
/// PIN: THE EXAMPLE IS ANOTHER SUBJECT'S. A local model copies the example it is shown, so the example is a bakery's
/// and a sheet that echoes its words is told so (`echoes`), as the flow plate's draft is (`PlateDraft.echoes`).
/// PIN: NEVER AN INVENTED ATTRIBUTION. A quote names who said it only when the person did; a line the model wrote
/// has no `by`, and the legend may say the lines are written for the plate. The plate holds this, not the prompt
/// (`PlateSheet.speakers`).
enum PlateSheetDraft {
    static let rules = """
    You design one editorial infographic plate: a header and a few blocks that say one idea well. It can be about anything: quotes, a creative piece, a story, an explanation of how something works, a process, a handful of figures. You answer with the plate's spec, one JSON object. The kit draws it in the Rao plate style; you decide what it says and which blocks say it.

    How a good plate reads:
    - One picture of one idea. `title` is a short editorial sentence with a turn of phrase, never a label (at most 30 characters). `subtitle` is the plate's thesis in one line (at most 100 characters). `caption` is "RAO STUDIOS · <SUBJECT> · THE <WHAT>" in capitals (at most 64 characters). `heading` (optional) names what the blocks walk through; `machine` (optional) is two to five words in capitals.
    - Then two to nine `blocks`, in reading order, on a grid of `columns`: 1, 2 or 3 (2 suits most; 1 for a few long quotes; 3 for many short ones). A block may `span` two or three columns to stand out.
    - `kind` says what a block is:
      - "quote": `text` the words, at most 220 characters; `by` who said them, only when the person named them in what they asked: quote those words as given. Otherwise write the lines yourself, with no `by`: the plate leaves off any speaker the person did not name. Never say the lines are sourced or attributed; when you wrote them, the `legend` says they were written for the plate.
      - "card": `title` and `text`: an idea, a fact, a definition, at most 260 characters.
      - "steps": `title` and `items`: what happens, in order, two to seven lines of at most 90 characters.
      - "list": `title` and `items`: things that belong together, two to seven lines.
      - "stat": `figure`, a number or short value ("72%", "3×", "1987"), and `title`, what it measures.
      - "flow": `title` and `items`: two to six stops of a few words each, joined by arrows: a process, a cycle, a path.
      - "drawing": a simple figure drawn in `paths`, SVG path data (M, L, H, V, C, Q, A, Z, numbers from 0 to 100) on a 100 × 100 square: one to twelve outlined strokes, never text. `title` names it. Use one when a shape says more than words: a sun, a wave, a mountain, a seedling, a key.
    - `colour` on a block: "gold", "blue", "green", "orange", "violet", "red", or "dial" for a quiet one. Colour by what blocks share, not one each; gold is the plate's accent.
    - `legend` (optional): one closing line under the blocks: a source, what the colours mean, or that the lines were written for the plate. `**word**` marks a term.
    - `tag` (optional): a line at the plate's foot: where it comes from.
    - Say it in your own words, for this subject and for this person's ask. State facts only when you are sure of them.
    """

    /// A plate on another subject: what the model copies the shape of.
    static let example = """
    {"caption": "RAO STUDIOS · THE BAKERY · THE RISE", "title": "One starter, every loaf",
     "subtitle": "flour, water and a day of patience: what a sourdough starter does, and why it takes its time",
     "heading": "A loaf, from the jar to the oven", "machine": "TWENTY-FOUR HOURS", "columns": 3,
     "blocks": [
      {"kind": "stat", "figure": "24 h", "title": "from feeding the starter to a cooled loaf", "colour": "gold"},
      {"kind": "flow", "title": "The rise", "items": ["feed the starter", "mix the dough", "fold and rest", "shape", "bake"], "span": 2, "colour": "gold"},
      {"kind": "card", "title": "What a starter is", "text": "Wild yeast and lactic bacteria living in flour and water. Fed each day, it raises the bread and gives it its sour.", "colour": "green"},
      {"kind": "steps", "title": "The night before", "items": ["feed the starter in the morning", "mix flour, water and starter at night", "leave it covered until it doubles"], "colour": "green"},
      {"kind": "drawing", "title": "A risen loaf", "paths": ["M12 72 Q50 18 88 72 Z", "M32 52 Q41 44 50 50", "M54 46 Q63 40 72 48"], "colour": "orange"},
      {"kind": "quote", "text": "Bread is a slow food in a fast world.", "span": 3, "colour": "dial"}],
     "legend": "Gold walks the day; green is what the starter is. The closing line was written for this plate.",
     "tag": "a plate of the bakery's method"}
    """

    static var system: String { rules + "\n\nA plate on another subject, to copy the shape of and never the words:\n" + example }

    static var reviseSystem: String {
        rules + "\n\nYou are fixing a plate you wrote, after it was drawn and measured. Keep every block the findings do not name; make the fewest changes that clear every finding. Answer with the whole spec, fixed."
    }

    static func draft(ask: String?, brief: String?, project: String, sources: PlateSources?) -> String {
        var parts: [String] = []
        if let ask, !ask.isEmpty { parts.append("The person asked: \"\(ask)\"") }
        if let brief, !brief.isEmpty { parts.append("What to draw: \(brief)") }
        if let sources, !sources.digest.isEmpty {
            parts.append("What the sources say (\(sources.files) files read in \(project)):\n\(sources.digest)")
        }
        parts.append("Write the plate's spec: an infographic of what the person asked for, in your own words.")
        return parts.joined(separator: "\n\n")
    }

    /// What a brief asks of an infographic drawn before.
    static func change(_ sheet: PlateSheet, brief: String) -> String {
        "The spec of a plate drawn before:\n\(json(sheet))\n\nWhat to change: \(brief)\n\nWrite the whole spec again, changed as asked and nothing else."
    }

    static func revise(_ sheet: PlateSheet, findings: [PlateFinding]) -> String {
        "The spec you wrote:\n\(json(sheet))\n\nWhat the plate measured:\n" + findings.prefix(16).map { "- " + $0.sentence }.joined(separator: "\n")
            + "\n\nWrite the whole spec again, fixed."
    }

    private static func json(_ sheet: PlateSheet) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(sheet)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    /// The example's own words a sheet must not carry: its title, and two-word runs of its blocks' text.
    static func echoes(_ sheet: PlateSheet) -> [PlateFinding] {
        var found: [PlateFinding] = []
        if sheet.title.lowercased() == "one starter, every loaf" {
            found.append(PlateFinding(.limit, "title", "the title is the example's: write this plate's own."))
        }
        for (index, block) in sheet.blocks.enumerated() {
            let words = [block.title, block.text, block.figure].compactMap { $0 } + block.items
            let shared = words.map(pairs).reduce(Set<String>()) { $0.union($1) }.intersection(examplePairs)
            if shared.count >= 3 {
                found.append(PlateFinding(.limit, "block:\(index + 1)",
                                          "\(PlateSheet.describe(index, block)) says the example's words (\(shared.sorted().prefix(3).joined(separator: ", "))): write this plate's own."))
            }
        }
        return found
    }

    private static let examplePairs: Set<String> = {
        guard let data = example.data(using: .utf8), let sheet = try? JSONDecoder().decode(PlateSheet.self, from: data) else { return [] }
        let words = sheet.blocks.flatMap { [$0.title, $0.text].compactMap { $0 } + $0.items }
        return words.map(pairs).reduce(Set<String>()) { $0.union($1) }
    }()

    /// Two-word runs of a text's longer words, lowercased: what tells copied wording from a shared word.
    private static func pairs(_ text: String) -> Set<String> {
        let words = text.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 3 }
        guard words.count > 1 else { return [] }
        return Set(zip(words, words.dropFirst()).map { $0 + " " + $1 })
    }

    /// The keys, as JSON Schema.
    static let schema: Data = {
        let text: [String: Any] = ["type": "string"]
        let colour: [String: Any] = ["type": "string", "enum": PlateColour.allCases.map(\.rawValue)]
        let block: [String: Any] = ["type": "object", "required": ["kind"], "properties": [
            "kind": ["type": "string", "enum": PlateBlock.Kind.allCases.map(\.rawValue)], "title": text, "text": text, "by": text, "figure": text,
            "items": ["type": "array", "items": text], "paths": ["type": "array", "items": text], "colour": colour, "span": ["type": "integer"]]]
        let sheet: [String: Any] = ["type": "object", "required": ["caption", "title", "subtitle", "blocks"], "properties": [
            "caption": text, "title": text, "subtitle": text, "heading": text, "machine": text, "tag": text, "legend": text,
            "columns": ["type": "integer"], "blocks": ["type": "array", "items": block]]]
        return (try? JSONSerialization.data(withJSONObject: sheet, options: [.sortedKeys])) ?? Data("{}".utf8)
    }()
}
