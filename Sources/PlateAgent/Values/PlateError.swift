import Foundation

/// What a call can say besides a plate.
public enum PlateError: Error, Equatable, CustomStringConvertible {
    /// No spec was given and the host offers no model to draft one.
    case noModel
    /// The spec file could not be read as a plate.
    case spec(String)
    /// The model's draft was not a plate: no lanes or no boxes.
    case empty(String)
    /// The plate's face or seal could not be found.
    case resources(tried: [String])
    /// WebKit did not load, measure or export the plate.
    case render(String)
    /// The PNG or the spec could not be written.
    case unwritable(String)

    public var description: String {
        switch self {
        case .noModel:
            return "plate drafts with the host's model, and this host has none: give it a `spec`, or call it from an app with a model loaded"
        case .spec(let reason): return "the spec could not be read: \(reason)"
        case .empty(let reason): return "the model's draft is not a plate: \(reason)"
        case .resources(let tried): return "the plate's face and seal were not found; looked in " + tried.joined(separator: ", ")
        case .render(let reason): return "WebKit could not render the plate: \(reason)"
        case .unwritable(let path): return "could not write \(path)"
        }
    }
}
