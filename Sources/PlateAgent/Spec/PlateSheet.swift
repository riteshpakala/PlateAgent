import Foundation

/// An infographic plate as the model writes it: the plates' header (caption, title, subtitle), an optional head over
/// the blocks, the blocks in reading order on a grid of one to three columns, and a closing line. Anything a person
/// may want on a plate that is not a system's structure: quotes, a creative piece, an explanation, a process, a
/// handful of figures. The grid, the type and the colours are the kit's (`PlateSheetKit`).
public struct PlateSheet: Codable, Sendable, Equatable {
    /// What a plate's embedded spec says it is: an infographic, not an architecture flow (`PlateSpec`).
    public static let form = "infographic"

    public var form = PlateSheet.form
    /// The small capitals over the title: `RAO STUDIOS · THE BAKERY · THE RISE`.
    public var caption: String
    /// A short editorial sentence: "One starter, every loaf".
    public var title: String
    /// The one-line thesis under it.
    public var subtitle: String
    /// The head of the card the blocks sit in.
    public var heading: String?
    /// The small capitals on the right of that head.
    public var machine: String?
    /// The foot of the plate.
    public var tag: String?
    /// One closing line under the blocks. `**word**` is bright, `{gold:words}` gold.
    public var legend: String?
    /// One to three; the kit picks when left out.
    public var columns: Int?
    public var blocks: [PlateBlock]

    public init(caption: String = "", title: String = "", subtitle: String = "", heading: String? = nil, machine: String? = nil,
                tag: String? = nil, legend: String? = nil, columns: Int? = nil, blocks: [PlateBlock] = []) {
        self.caption = caption; self.title = title; self.subtitle = subtitle; self.heading = heading; self.machine = machine
        self.tag = tag; self.legend = legend; self.columns = columns; self.blocks = blocks
    }

    enum CodingKeys: String, CodingKey { case form, caption, title, subtitle, heading, machine, tag, legend, columns, blocks }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        caption = PlateLoose.string(c, .caption) ?? ""
        title = PlateLoose.string(c, .title) ?? ""
        subtitle = PlateLoose.string(c, .subtitle) ?? ""
        heading = PlateLoose.string(c, .heading)?.nonEmptyText
        machine = PlateLoose.string(c, .machine)?.nonEmptyText
        tag = PlateLoose.string(c, .tag)?.nonEmptyText
        legend = PlateLoose.string(c, .legend)?.nonEmptyText
        columns = PlateLoose.int(c, .columns)
        blocks = PlateLoose.list(c, .blocks, of: PlateBlock.self)
    }

    /// Whether a spec's JSON is an infographic's: it says so, or it holds blocks and no lanes.
    static func isSheet(_ json: Data) -> Bool {
        guard let object = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return false }
        if let form = object["form"] as? String { return form == PlateSheet.form }
        return object["blocks"] != nil && object["lanes"] == nil
    }

    /// The columns the blocks are laid on: as written, else two for most plates, one for a single block, three for
    /// many small ones.
    var grid: Int {
        if let columns { return min(max(columns, 1), 3) }
        switch blocks.count {
        case 0, 1: return 1
        case 2...4: return 2
        default: return blocks.allSatisfy { [.stat, .quote, .card].contains($0.kind) } && blocks.count % 3 == 0 ? 3 : 2
        }
    }
}
