import Foundation

/// One block of an infographic plate, as the model writes it: what kind of thing it is and its words. The kit draws
/// each kind in the plates' style; the model never says where a block goes beyond how many columns it spans.
public struct PlateBlock: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// Words as someone said them, and who, when it is known.
        case quote
        /// An idea, a fact or a definition: a title and a few lines.
        case card
        /// What happens, in order, numbered.
        case steps
        /// Things that belong together.
        case list
        /// One figure and what it measures.
        case stat
        /// A few stops joined by arrows: a process, a cycle, a path.
        case flow
        /// A simple figure drawn in strokes on a 100 × 100 square.
        case drawing

        /// A kind a model named loosely: `fact` is a card, `numbers` a list, `process` a flow; an unknown name a card.
        public init(loose name: String) {
            let word = name.lowercased().trimmingCharacters(in: .whitespaces)
            if let kind = Kind(rawValue: word) { self = kind; return }
            switch word {
            case "quotation", "saying", "epigraph": self = .quote
            case "step", "timeline", "howto", "how-to", "numbered": self = .steps
            case "bullets", "items", "points": self = .list
            case "number", "figure", "metric", "statistic": self = .stat
            case "process", "cycle", "path", "sequence", "arrows": self = .flow
            case "illustration", "sketch", "picture", "figure-drawing", "icon": self = .drawing
            default: self = .card
            }
        }

        public init(from decoder: Decoder) throws {
            self.init(loose: (try? decoder.singleValueContainer().decode(String.self)) ?? "")
        }
    }

    public var kind: Kind
    /// A card's, a list's, a flow's or a drawing's heading; what a stat measures.
    public var title: String?
    /// A quote's words; a card's lines.
    public var text: String?
    /// Who said a quote. Never invented: an unattributed line has none.
    public var by: String?
    /// A stat's value: "72%", "3×", "1987".
    public var figure: String?
    /// A list's, a steps' or a flow's lines.
    public var items: [String]
    /// A drawing's strokes: SVG path data on a 100 × 100 square.
    public var paths: [String]
    public var colour: PlateColour?
    /// How many of the plate's columns it takes; one when left out.
    public var span: Int?

    public init(kind: Kind, title: String? = nil, text: String? = nil, by: String? = nil, figure: String? = nil, items: [String] = [],
                paths: [String] = [], colour: PlateColour? = nil, span: Int? = nil) {
        self.kind = kind; self.title = title; self.text = text; self.by = by; self.figure = figure; self.items = items
        self.paths = paths; self.colour = colour; self.span = span
    }

    enum CodingKeys: String, CodingKey { case kind, title, text, by, figure, items, paths, colour, span }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decodeIfPresent(Kind.self, forKey: .kind)) ?? .card
        title = PlateLoose.string(c, .title)?.nonEmptyText
        text = PlateLoose.string(c, .text)?.nonEmptyText
        // The kit draws the dash; a model often writes its own ("—Seneca").
        by = PlateLoose.string(c, .by)?.trimmingCharacters(in: CharacterSet(charactersIn: "-–—~ ").union(.whitespacesAndNewlines)).nonEmptyText
        figure = PlateLoose.string(c, .figure)?.nonEmptyText
        // A model writes a list as a list, or as one string of lines.
        items = PlateLoose.list(c, .items, of: String.self)
        if items.isEmpty, let lines = PlateLoose.string(c, .items) {
            items = lines.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        paths = PlateLoose.list(c, .paths, of: String.self)
        colour = try? c.decodeIfPresent(PlateColour.self, forKey: .colour)
        span = PlateLoose.int(c, .span)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(by, forKey: .by)
        try c.encodeIfPresent(figure, forKey: .figure)
        if !items.isEmpty { try c.encode(items, forKey: .items) }
        if !paths.isEmpty { try c.encode(paths, forKey: .paths) }
        try c.encodeIfPresent(colour, forKey: .colour)
        try c.encodeIfPresent(span, forKey: .span)
    }
}

extension String {
    /// The text, or nil when it is only spaces.
    var nonEmptyText: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
