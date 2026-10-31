import Foundation

/// Where a plate's parts go, in CSS pixels on the 1600-wide page: the measures of Craft's flow plate
/// (docs/README_Assets/src/plates.py, `flow()`), made rules. The card the lanes sit in starts under the header;
/// the header script moves it to the header's rhythm afterwards.
enum PlateGeometry {
    static let cardX = 70.0
    static let cardY = 374.0
    static let cardW = 1460.0
    /// Under the card's foot: the legend's last line to the card's edge.
    static let cardFoot = 30.0
    /// The page's foot under the card, where the tag sits.
    static let pageFoot = 76.0

    static let laneX = 110.0
    static let laneW = 1380.0
    static let firstLane = 444.0
    static let laneGap = 22.0
    /// Between two lanes side by side.
    static let pairGap = 40.0
    /// A lane's inside: its boxes start this far in from its sides and top, and its foot holds its name.
    static let laneSide = 20.0
    static let laneTop = 18.0
    static let laneFoot = 44.0

    static let columnGap = 24.0
    static let rowGap = 24.0
    /// The widest a box grows in a lane of few boxes: wider than this reads as a banner, not a part.
    static let maxCell = 440.0

    /// A box under another: the gap between them, and between boxes side by side under one.
    static let underGap = 32.0
    static let childGap = 16.0

    static let agentHeight = 58.0
    static let agentMaxWidth = 170.0
    static let minNode = 64.0
    /// Under a box's last line: the measured content ends here.
    static let nodeFoot = 12.0
    static let minExternal = 46.0
    static let externalPad = 4.0

    /// Outside the lanes, where an arrow that would cross a box goes round.
    static let gutter = 18.0
    static let uRun = 26.0

    static let wireHeight = 18.0
    static let markRadius = 11.0

    static let legendX = 130.0
    static let legendW = 1340.0
    static let legendGap = 18.0
    static let legendSize = 15.0
}
