import Foundation

/// The plate's colours, by name: what a lane, a box's bar or an arrow is drawn in. The values are the Rao plates'.
public enum PlateColour: String, Codable, Sendable, CaseIterable {
    case gold, blue, green, orange, violet, red
    /// The light grey of a front end's bar.
    case line
    /// The dim grey of a lane that frames, of an observer's dashed arrow.
    case dial

    public var hex: String {
        switch self {
        case .gold: return "#c7a659"
        case .blue: return "#5e8fda"
        case .green: return "#28a883"
        case .orange: return "#d8773f"
        case .violet: return "#a88bd6"
        case .red: return "#d9645a"
        case .line: return "#cbc8c0"
        case .dial: return "#8b8a84"
        }
    }

    /// A colour a model named loosely: `grey` is the dial, `white` the line, `yellow` gold, `purple` violet; an
    /// unknown name is the dial.
    public init(loose name: String) {
        let word = name.lowercased().trimmingCharacters(in: .whitespaces)
        if let colour = PlateColour(rawValue: word) { self = colour; return }
        switch word {
        case "grey", "gray", "muted", "neutral": self = .dial
        case "white", "light", "silver", "platinum": self = .line
        case "yellow", "amber", "brass": self = .gold
        case "purple", "lilac": self = .violet
        case "teal", "emerald": self = .green
        case "sky", "indigo": self = .blue
        case "rust", "copper": self = .orange
        case "crimson", "pink": self = .red
        default: self = .dial
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(loose: (try? decoder.singleValueContainer().decode(String.self)) ?? "")
    }
}
