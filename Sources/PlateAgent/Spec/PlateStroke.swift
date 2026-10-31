import Foundation

/// How an arrow is drawn, which says what it is: a dispatch, an agent's run and what it writes, or an observer
/// calling back and a process across a wire.
public enum PlateStroke: String, Codable, Sendable, CaseIterable {
    /// Solid, in the colour of the box it leaves: a call, a dispatch down the graph.
    case solid
    /// Dashed gold: an agent's run, and what it writes back.
    case dashedGold
    /// Dashed grey: something observed and called back, or a process across a wire.
    case dashedGrey

    /// A stroke a model named loosely; an unknown stroke is solid.
    public init(loose name: String) {
        let word = name.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        switch word {
        case "dashedgold", "gold", "run", "agent", "agentrun", "stream", "writes": self = .dashedGold
        case "dashedgrey", "dashedgray", "dashed", "grey", "gray", "observe", "observer", "wire", "process", "callback", "dotted": self = .dashedGrey
        default: self = .solid
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(loose: (try? decoder.singleValueContainer().decode(String.self)) ?? "")
    }
}
