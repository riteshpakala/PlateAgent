import Foundation

/// What a plate is: an architecture flow drawn from a project's code (lanes of parts, who calls whom, the walk), or an
/// infographic of anything else (blocks: quotes, cards, steps, figures, a flow of stops, a drawing).
///
/// PIN: THE CODE DECIDES WHEN NOTHING ELSE DOES. A call that says its form gets it. Otherwise sources that hold a
/// code graph of two parts or more are drawn as its architecture, and everything else is an infographic: asked for
/// inspirational quotes, the plate drew "One quote, every line" as lanes of a project's files (2026-11-04).
enum PlateForm: String, Sendable, Equatable {
    case architecture
    case infographic

    /// A form a caller named loosely: `flow` and `system` are the architecture; `sheet`, `poster` and `quotes` an
    /// infographic; anything else, nil.
    init?(loose name: String?) {
        guard let word = name?.lowercased().trimmingCharacters(in: .whitespaces), !word.isEmpty else { return nil }
        switch word {
        case "architecture", "flow", "system", "structure", "services", "code": self = .architecture
        case "infographic", "sheet", "poster", "quotes", "quote", "explainer", "explanation", "creative", "drawing", "card", "cards": self = .infographic
        default: return nil
        }
    }

    /// The form a call draws: as it says, else the architecture when its sources hold a graph, else an infographic.
    static func chosen(_ named: String?, graph: PlateGraph?) -> PlateForm {
        if let form = PlateForm(loose: named) { return form }
        return (graph?.parts.count ?? 0) >= 2 ? .architecture : .infographic
    }
}
