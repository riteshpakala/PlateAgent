import Foundation

/// What a call answers: the PNG written and the spec beside it, how big the PNG is, how many rounds it took,
/// and what the last round still found. The spec itself is in the file, so a host's model reads a short answer.
public struct PlateResult: Codable, Sendable, Equatable {
    /// The PNG, as an absolute path.
    public var path: String
    /// The PNG and the spec written beside it (`<name>.plate.json`): what a host counts as the work's changes.
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

    public init(path: String, paths: [String], width: Int, height: Int, rounds: Int, findings: [String], title: String,
                lanes: Int, nodes: Int, edges: Int) {
        self.path = path; self.paths = paths; self.width = width; self.height = height; self.rounds = rounds
        self.findings = findings; self.title = title; self.lanes = lanes; self.nodes = nodes; self.edges = edges
    }
}
