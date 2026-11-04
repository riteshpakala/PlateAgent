import Foundation

/// What a call answers: the PNG written (its spec inside it), how big the PNG is, how many rounds it took,
/// and what the last round still found. The spec itself is in the file, so a host's model reads a short answer.
public struct PlateResult: Codable, Sendable, Equatable {
    /// The PNG, as an absolute path.
    public var path: String
    /// What the call wrote: the PNG. What a host counts as the work's changes.
    public var paths: [String]
    /// In pixels: twice the plate's CSS size.
    public var width: Int
    public var height: Int
    public var rounds: Int
    /// What the plate written still has wrong, one sentence each; empty when it measured clean.
    public var findings: [String]
    public var title: String
    public var lanes: Int
    public var nodes: Int
    public var edges: Int
    /// What the plate is: "architecture", a flow drawn from the code, or "infographic", blocks of anything.
    public var form: String
    /// An infographic's blocks; none for an architecture flow.
    public var blocks: Int
    /// What the calling model is told when findings are left: the call is done.
    ///
    /// PIN: FINDINGS LEFT ARE THE PLATE'S, NOT THE CALLER'S. A calling model that reads findings in an answer calls
    /// again, rewording its brief to fix them (a title it took for the brief's length), and draws the same plate
    /// until its turn runs out; one did, 21 times. So an answer with findings says the call is done.
    public var note: String?

    public init(path: String, paths: [String], width: Int, height: Int, rounds: Int, findings: [String], title: String,
                lanes: Int, nodes: Int, edges: Int, form: String = "architecture", blocks: Int = 0) {
        self.path = path; self.paths = paths; self.width = width; self.height = height; self.rounds = rounds
        self.findings = findings; self.title = title; self.lanes = lanes; self.nodes = nodes; self.edges = edges
        self.form = form; self.blocks = blocks
        self.note = findings.isEmpty ? nil
            : "The PNG is written and this call is done. The findings are what the plate's own drawing kept after \(rounds) \(rounds == 1 ? "round" : "rounds") of fixing: calling again with the same brief draws the same plate, so tell the person what is left instead of calling again."
    }
}
