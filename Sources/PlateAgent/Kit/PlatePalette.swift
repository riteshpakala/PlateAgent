import Foundation

/// The plate's measures and type, as the Rao plates set them (Craft's docs/README_Assets/src/plates.py, after AII's
/// and Veil's): a 1600-wide page, the header's rhythm, and the faces.
enum PlatePalette {
    /// The page's width in CSS pixels; the PNG is twice it.
    static let width = 1600.0
    /// The header's rhythm: the mark's ink 70.5 px from the top and the left, the title's ink 174 px down, what
    /// follows 54 px under the subtitle's baseline.
    static let ink = 70.5
    static let titleInk = 174.0
    static let headerGap = 54.0
    static let mono = "Menlo, 'SF Mono', monospace"
    static let sans = "-apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif"
    /// Menlo's advance, as a fraction of its size: what a mono label's width is estimated from.
    static let monoAdvance = 0.6021
}
