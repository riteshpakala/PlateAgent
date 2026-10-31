import Foundation

/// A box: a part of the system, in a lane. Its name is the type or module; its duty is one sentence of what it is
/// responsible for and nothing else; its code line is where it lives, or what it answers to.
public struct PlateNode: Codable, Sendable, Equatable {
    public var id: String
    /// The lane it sits in, by the lane's id.
    public var lane: String
    public var name: String
    public var duty: String?
    public var code: String?
    public var kind: PlateNodeKind?
    /// Its bar's colour; its lane's when left out (the line's, in a dial lane).
    public var colour: PlateColour?
    /// Which column of its lane's row, from 1; the next free cell when left out.
    public var column: Int?
    /// How many columns it spans; one when left out.
    public var span: Int?
    /// Drawn under this box, by its id, inside the same column: an agent a service runs, a store it reaches.
    public var under: String?

    public init(id: String, lane: String, name: String, duty: String? = nil, code: String? = nil, kind: PlateNodeKind? = nil,
                colour: PlateColour? = nil, column: Int? = nil, span: Int? = nil, under: String? = nil) {
        self.id = id; self.lane = lane; self.name = name; self.duty = duty; self.code = code; self.kind = kind
        self.colour = colour; self.column = column; self.span = span; self.under = under
    }

    enum CodingKeys: String, CodingKey { case id, lane, name, duty, code, kind, colour, color, column, span, under }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = PlateLoose.string(c, .name) ?? ""
        id = PlateLoose.string(c, .id) ?? PlateLoose.slug(name)
        self.name = name.isEmpty ? id : name
        lane = PlateLoose.string(c, .lane) ?? ""
        duty = PlateLoose.string(c, .duty)
        code = PlateLoose.string(c, .code)
        kind = try? c.decodeIfPresent(PlateNodeKind.self, forKey: .kind)
        colour = (try? c.decodeIfPresent(PlateColour.self, forKey: .colour)) ?? (try? c.decodeIfPresent(PlateColour.self, forKey: .color))
        column = PlateLoose.int(c, .column)
        span = PlateLoose.int(c, .span)
        under = PlateLoose.string(c, .under).flatMap { $0.isEmpty ? nil : $0 }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(lane, forKey: .lane); try c.encode(name, forKey: .name)
        try c.encodeIfPresent(duty, forKey: .duty); try c.encodeIfPresent(code, forKey: .code); try c.encodeIfPresent(kind, forKey: .kind)
        try c.encodeIfPresent(colour, forKey: .colour); try c.encodeIfPresent(column, forKey: .column)
        try c.encodeIfPresent(span, forKey: .span); try c.encodeIfPresent(under, forKey: .under)
    }
}
