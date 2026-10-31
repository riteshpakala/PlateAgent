import Foundation

/// The plate as the model writes it: the header, the lanes in the order the thing flows, the boxes in them, the
/// arrows between them, and the legend. Flat and short, so a local model writes it in one answer; the layout,
/// the strokes and the type are the kit's.
public struct PlateSpec: Codable, Sendable, Equatable {
    /// The small capitals over the title: `RAO STUDIOS · CRAFT · THE FLOW`.
    public var caption: String
    /// A short editorial sentence: "One turn, every service".
    public var title: String
    /// The one-line thesis under it.
    public var subtitle: String
    /// The head of the card the lanes sit in: "A turn, through the services".
    public var heading: String?
    /// The small capitals on the right of that head: "ONE ASK, END TO END".
    public var machine: String?
    /// The foot of the plate: where every box lives.
    public var tag: String?
    public var lanes: [PlateLane]
    public var nodes: [PlateNode]
    public var edges: [PlateEdge]
    /// What the strokes and the numbers mean, under the lanes. `**word**` is bright, `{gold:words}` gold.
    public var legend: String?

    public init(caption: String = "", title: String = "", subtitle: String = "", heading: String? = nil, machine: String? = nil,
                tag: String? = nil, lanes: [PlateLane] = [], nodes: [PlateNode] = [], edges: [PlateEdge] = [], legend: String? = nil) {
        self.caption = caption; self.title = title; self.subtitle = subtitle; self.heading = heading; self.machine = machine
        self.tag = tag; self.lanes = lanes; self.nodes = nodes; self.edges = edges; self.legend = legend
    }

    enum CodingKeys: String, CodingKey { case caption, title, subtitle, heading, machine, tag, lanes, nodes, edges, legend }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        caption = PlateLoose.string(c, .caption) ?? ""
        title = PlateLoose.string(c, .title) ?? ""
        subtitle = PlateLoose.string(c, .subtitle) ?? ""
        heading = PlateLoose.string(c, .heading)
        machine = PlateLoose.string(c, .machine)
        tag = PlateLoose.string(c, .tag)
        lanes = PlateLoose.list(c, .lanes, of: PlateLane.self)
        nodes = PlateLoose.list(c, .nodes, of: PlateNode.self)
        edges = PlateLoose.list(c, .edges, of: PlateEdge.self)
        legend = PlateLoose.string(c, .legend)
    }

    /// The lane `id` names.
    public func lane(_ id: String) -> PlateLane? { lanes.first { $0.id == id } }
    /// The box `id` names.
    public func node(_ id: String) -> PlateNode? { nodes.first { $0.id == id } }
}
