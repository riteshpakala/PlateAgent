import Foundation

/// A plate as WebKit drew it: the PNG, its size in pixels, and what the measure found.
struct PlateRendered: Sendable {
    let png: Data
    let width: Int
    let height: Int
    let raw: PlateMeasure.Raw
}
