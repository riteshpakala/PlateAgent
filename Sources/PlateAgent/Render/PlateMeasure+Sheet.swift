import Foundation

/// What an infographic plate measured, said so the model that wrote it can fix it: a title or subtitle that runs past
/// the plate's edge even drawn at its smallest, and a plate taller than one picture reads.
extension PlateMeasure {
    /// The tallest an infographic reads as one picture, in CSS pixels: about twice the page's width.
    static let sheetTallest = 4200.0

    static func findings(_ raw: Raw, sheet: PlateSheet, height: Double) -> [PlateFinding] {
        var found: [PlateFinding] = []
        let edge = PlatePalette.width - PlateGeometry.cardX
        if raw.title > edge {
            found.append(PlateFinding(.overflow, "title", numbers: [Int(raw.title), Int(edge)],
                                      "the title runs to \(Int(raw.title)) px and the plate ends at \(Int(edge)): keep it under about \(PlateSheet.Limits.title - 4) characters."))
        }
        if raw.subtitle > edge, !sheet.subtitle.isEmpty {
            found.append(PlateFinding(.overflow, "subtitle", numbers: [Int(raw.subtitle), Int(edge)],
                                      "the subtitle runs to \(Int(raw.subtitle)) px and the plate ends at \(Int(edge)): say it in about \(Int(Double(sheet.subtitle.count) * edge / raw.subtitle) - 4) characters."))
        }
        if height > sheetTallest {
            found.append(PlateFinding(.limit, "blocks", numbers: [Int(height), Int(sheetTallest)],
                                      "the plate is \(Int(height)) px tall and reads as one picture under \(Int(sheetTallest)): use fewer blocks, shorter lines, or one more column."))
        }
        return found
    }
}
