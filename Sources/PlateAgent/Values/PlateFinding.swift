import Foundation

/// One thing wrong with a plate, said so the model that wrote the spec can fix it: what kind of thing, which
/// element, the numbers that show it, and one sentence that says what to change.
public struct PlateFinding: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        /// A text or a count past what the plate holds.
        case limit
        /// An id that nothing declares.
        case unknown
        /// A text wider or taller than its box.
        case overflow
        /// Two things drawn on top of each other.
        case overlap
        /// Something past the plate's edge.
        case outside
        /// An arrow drawn through a box that is neither of its ends.
        case crossing
    }

    public var kind: Kind
    /// `node:<id>`, `edge:<n>`, `wire:<n>`, `lane:<id>`, `title`, `subtitle`, `legend`.
    public var element: String
    public var numbers: [Int]
    public var sentence: String

    public init(_ kind: Kind, _ element: String, numbers: [Int] = [], _ sentence: String) {
        self.kind = kind; self.element = element; self.numbers = numbers; self.sentence = sentence
    }
}
