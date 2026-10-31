import Foundation

/// What a run streams while it works: the sources read, the spec drafted, each round measured and revised, and
/// the plate written.
public enum PlateFrame: Sendable {
    case read(files: Int, characters: Int)
    case drafted(PlateSpec)
    case measured(round: Int, findings: [PlateFinding])
    case revised(round: Int)
    case written(PlateResult)

    /// The answer, when this frame carries it.
    public var result: PlateResult? {
        if case .written(let result) = self { return result }
        return nil
    }
}
