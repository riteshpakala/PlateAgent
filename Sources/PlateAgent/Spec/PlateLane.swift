import Foundation

/// A lane: a tier of the system, drawn as a tinted band its boxes sit in, its name in small capitals at its foot.
/// Lanes run top to bottom in the order the thing flows.
public struct PlateLane: Codable, Sendable, Equatable {
    public var id: String
    /// "the front ends", "a turn", "the project": drawn in capitals.
    public var name: String
    public var colour: PlateColour
    /// How many boxes a row holds; the count of boxes, up to four (two in a lane beside another), when left out.
    public var columns: Int?
    /// Drawn in the same row as the lane before it, the two side by side.
    public var beside: Bool?
    /// One line no box says, set beside the lane's boxes: what holds the lane together ("the handlers: memory held »
    /// halt the turns"). `{dial:words}` dims a lead-in.
    public var note: String?

    public init(id: String, name: String, colour: PlateColour, columns: Int? = nil, beside: Bool? = nil, note: String? = nil) {
        self.id = id; self.name = name; self.colour = colour; self.columns = columns; self.beside = beside; self.note = note
    }

    enum CodingKeys: String, CodingKey { case id, name, colour, color, columns, beside, note }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = PlateLoose.string(c, .name) ?? ""
        id = PlateLoose.string(c, .id) ?? PlateLoose.slug(name)
        self.name = name.isEmpty ? id : name
        colour = (try? c.decodeIfPresent(PlateColour.self, forKey: .colour)) ?? (try? c.decodeIfPresent(PlateColour.self, forKey: .color)) ?? .dial
        columns = PlateLoose.int(c, .columns)
        beside = PlateLoose.bool(c, .beside)
        note = PlateLoose.string(c, .note).flatMap { $0.isEmpty ? nil : $0 }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(colour, forKey: .colour)
        try c.encodeIfPresent(columns, forKey: .columns); try c.encodeIfPresent(beside, forKey: .beside); try c.encodeIfPresent(note, forKey: .note)
    }
}
