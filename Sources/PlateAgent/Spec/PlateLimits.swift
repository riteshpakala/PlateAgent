import Foundation

/// What one plate holds. Past these, text overflows its box or the plate stops reading as one picture; a spec
/// past them gets a finding the model can act on, never a crash, and the last round clamps it so a PNG is
/// still written.
enum PlateLimits {
    static let lanes = 6
    static let nodesPerLane = 8
    static let edges = 24
    /// The numbers walk one path: more than this is a list, not a walk.
    static let numbers = 12
    static let caption = 64
    /// At 104 px of Playfair italic, about 45 px a character: 30 fill the card.
    static let title = 30
    static let subtitle = 110
    static let heading = 60
    static let name = 28
    static let duty = 110
    static let code = 56
    static let label = 36
    static let laneNote = 140
    static let legend = 360
    static let tag = 140
}
