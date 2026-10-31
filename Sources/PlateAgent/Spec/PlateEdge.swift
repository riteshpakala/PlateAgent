import Foundation

/// An arrow from one box to another: what it carries in one to three mono words, and, when it is a step of the one
/// path the plate walks, its number.
public struct PlateEdge: Codable, Sendable, Equatable {
    public var from: String
    public var to: String
    public var label: String?
    /// Its step on the walk, from 1; the numbers walk one path end to end.
    public var number: Int?
    public var style: PlateStroke?
    /// Its colour; the colour of the box it leaves when left out (gold for a run, the dial for an observer).
    public var colour: PlateColour?
    /// A head at both ends: a process across a wire, a pair that talk both ways.
    public var both: Bool?

    public init(from: String, to: String, label: String? = nil, number: Int? = nil, style: PlateStroke? = nil,
                colour: PlateColour? = nil, both: Bool? = nil) {
        self.from = from; self.to = to; self.label = label; self.number = number; self.style = style
        self.colour = colour; self.both = both
    }

    enum CodingKeys: String, CodingKey { case from, to, label, number, style, colour, color, both }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        from = PlateLoose.string(c, .from) ?? ""
        to = PlateLoose.string(c, .to) ?? ""
        label = PlateLoose.string(c, .label).flatMap { $0.isEmpty ? nil : $0 }
        number = PlateLoose.int(c, .number)
        style = try? c.decodeIfPresent(PlateStroke.self, forKey: .style)
        colour = (try? c.decodeIfPresent(PlateColour.self, forKey: .colour)) ?? (try? c.decodeIfPresent(PlateColour.self, forKey: .color))
        both = PlateLoose.bool(c, .both)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(from, forKey: .from); try c.encode(to, forKey: .to)
        try c.encodeIfPresent(label, forKey: .label); try c.encodeIfPresent(number, forKey: .number)
        try c.encodeIfPresent(style, forKey: .style); try c.encodeIfPresent(colour, forKey: .colour); try c.encodeIfPresent(both, forKey: .both)
    }
}
