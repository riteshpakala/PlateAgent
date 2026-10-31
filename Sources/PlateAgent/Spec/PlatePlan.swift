import Foundation

/// What the model decides about a plate when the code's graph is known: the header, the lanes and which parts sit in
/// each, a line of duty where the code's own reads badly, the walk the numbers take, and anything across a wire. Short,
/// so a local model writes it in a minute; the package composes the plate from it and the graph (`PlateCompose`).
public struct PlatePlan: Codable, Sendable, Equatable {
    public struct Lane: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var colour: PlateColour
        public var beside: Bool?
        public var note: String?
        /// The parts in it, by their names in the graph, in the order they read.
        public var boxes: [String]

        public init(id: String, name: String, colour: PlateColour, beside: Bool? = nil, note: String? = nil, boxes: [String]) {
            self.id = id; self.name = name; self.colour = colour; self.beside = beside; self.note = note; self.boxes = boxes
        }

        enum CodingKeys: String, CodingKey { case id, name, colour, color, beside, note, boxes, parts }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let name = PlateLoose.string(c, .name) ?? ""
            id = PlateLoose.string(c, .id) ?? PlateLoose.slug(name)
            self.name = name.isEmpty ? id : name
            colour = (try? c.decodeIfPresent(PlateColour.self, forKey: .colour)) ?? (try? c.decodeIfPresent(PlateColour.self, forKey: .color)) ?? .dial
            beside = PlateLoose.bool(c, .beside)
            note = PlateLoose.string(c, .note).flatMap { $0.isEmpty ? nil : $0 }
            let boxes = PlateLoose.list(c, .boxes, of: String.self)
            self.boxes = boxes.isEmpty ? PlateLoose.list(c, .parts, of: String.self) : boxes
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(colour, forKey: .colour)
            try c.encodeIfPresent(beside, forKey: .beside); try c.encodeIfPresent(note, forKey: .note); try c.encode(boxes, forKey: .boxes)
        }
    }

    /// A step of the walk: an arrow the numbers take, in order.
    public struct Step: Codable, Sendable, Equatable {
        public var from: String
        public var to: String
        public var label: String?

        public init(from: String, to: String, label: String? = nil) { self.from = from; self.to = to; self.label = label }

        enum CodingKeys: String, CodingKey { case from, to, label }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            from = PlateLoose.string(c, .from) ?? ""
            to = PlateLoose.string(c, .to) ?? ""
            label = PlateLoose.string(c, .label).flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    /// Something across a wire: an engine, a server, a store a part reaches.
    public struct External: Codable, Sendable, Equatable {
        public var name: String
        /// The part it hangs under.
        public var under: String
        public var what: String?

        public init(name: String, under: String, what: String? = nil) { self.name = name; self.under = under; self.what = what }

        enum CodingKeys: String, CodingKey { case name, under, what }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = PlateLoose.string(c, .name) ?? ""
            under = PlateLoose.string(c, .under) ?? ""
            what = PlateLoose.string(c, .what).flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    /// What one pass of the walk carries ("turn", "request"), where it starts ("ask") and what it leaves ("records"),
    /// and what the plate shows ("flow"): the header is made of them (`PlateCompose.header`).
    public var unit: String?
    public var start: String?
    public var end: String?
    public var subject: String?
    /// The root's lane note: what the root does that no box says.
    public var rootNote: String?
    /// The header as written, when a plan writes it; else made of the words above.
    public var caption: String
    public var title: String
    public var subtitle: String
    public var heading: String?
    public var machine: String?
    public var tag: String?
    public var legend: String?
    public var lanes: [Lane]
    /// A part's duty, by its name, where the code's own line reads badly or runs long.
    public var duties: [String: String]
    public var walk: [Step]
    public var externals: [External]

    public init(unit: String? = nil, start: String? = nil, end: String? = nil, subject: String? = nil, rootNote: String? = nil,
                caption: String = "", title: String = "", subtitle: String = "", heading: String? = nil, machine: String? = nil,
                tag: String? = nil, legend: String? = nil, lanes: [Lane] = [], duties: [String: String] = [:], walk: [Step] = [],
                externals: [External] = []) {
        self.unit = unit; self.start = start; self.end = end; self.subject = subject; self.rootNote = rootNote
        self.caption = caption; self.title = title; self.subtitle = subtitle; self.heading = heading; self.machine = machine
        self.tag = tag; self.legend = legend; self.lanes = lanes; self.duties = duties; self.walk = walk; self.externals = externals
    }

    enum CodingKeys: String, CodingKey {
        case unit, start, end, subject, rootNote, caption, title, subtitle, heading, machine, tag, legend, lanes, duties, walk, externals
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func word(_ key: CodingKeys) -> String? { PlateLoose.string(c, key).map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 } }
        unit = word(.unit); start = word(.start); end = word(.end); subject = word(.subject); rootNote = word(.rootNote)
        caption = PlateLoose.string(c, .caption) ?? ""
        title = PlateLoose.string(c, .title) ?? ""
        subtitle = PlateLoose.string(c, .subtitle) ?? ""
        heading = PlateLoose.string(c, .heading)
        machine = PlateLoose.string(c, .machine)
        tag = PlateLoose.string(c, .tag)
        legend = PlateLoose.string(c, .legend)
        lanes = PlateLoose.list(c, .lanes, of: Lane.self)
        duties = ((try? c.decodeIfPresent([String: String].self, forKey: .duties)) ?? nil) ?? [:]
        walk = PlateLoose.list(c, .walk, of: Step.self)
        externals = PlateLoose.list(c, .externals, of: External.self)
    }
}
