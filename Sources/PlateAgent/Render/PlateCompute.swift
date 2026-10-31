import Foundation

/// What every plate is drawn with: one WebKit page and the face and seal, made on the first call and kept.
///
/// PIN: nothing at bootstrap. An app that links the package and never asks for a plate makes no page and reads no
/// font; the first call does both, on main, where WebKit lives.
@MainActor
public final class PlateCompute {
    private var renderer: PlateRenderer?
    private var loaded: PlateKit.Faces?

    public init() {}

    func faces() throws -> PlateKit.Faces {
        if let loaded { return loaded }
        let faces = try PlateResources.faces()
        loaded = faces
        return faces
    }

    private var page: PlateRenderer {
        if let renderer { return renderer }
        let made = PlateRenderer()
        renderer = made
        return made
    }

    /// What each box says, measured at its width.
    func measures(_ spec: PlateSpec, grid: PlateGrid) async throws -> PlateMeasures {
        try await page.measures(PlateMeasure.page(spec, grid: grid, faces: faces()))
    }

    /// The page drawn, measured and exported.
    func render(_ html: String) async throws -> PlateRendered {
        try await page.render(html)
    }
}
