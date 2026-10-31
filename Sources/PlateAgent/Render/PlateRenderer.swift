import Foundation
import ImageIO
import WebKit

/// The plate in WebKit, with no window: one `WebPage`, a page loaded at a time.
///
/// PIN: measured at 1x, exported at 2x by zoom. A headless page has a scale of one and `snapshotWidth` does not
/// enlarge it (spike, 2026-10-30: 3200 asked, 1600 given), so the page is settled and measured as drawn and then
/// zoomed to 2 for the export: WebKit lays the type out again at twice the size, so the PNG is sharp, not scaled up.
@MainActor
final class PlateRenderer {
    private let page = WebPage()

    func load(_ html: String) async throws {
        do {
            for try await event in page.load(html: html) where event == .finished { return }
        } catch {
            throw PlateError.render("the page did not load: \(error)")
        }
    }

    /// Each box's height at its width, and the legend's.
    func measures(_ html: String) async throws -> PlateMeasures {
        try await load(html)
        let json = try await page.callJavaScript(PlateMeasure.heightsScript) as? String ?? "{}"
        return PlateMeasure.measures(json)
    }

    /// The plate settled to the header's rhythm, measured, and exported at 2x.
    func render(_ html: String) async throws -> PlateRendered {
        try await load(html)
        _ = try await page.callJavaScript("return await window.__plate.settle()")
        let json = try await page.callJavaScript(PlateMeasure.findingsScript) as? String ?? "{}"
        let raw = (try? JSONDecoder().decode(PlateMeasure.Raw.self, from: Data(json.utf8)))
            ?? PlateMeasure.Raw(overflow: [], overlaps: [], outside: [], title: 0, subtitle: 0)
        _ = try await page.callJavaScript("document.documentElement.style.zoom = '2'; return 1")
        let png: Data
        do {
            png = try await page.exported(as: .image(region: .contents))
        } catch {
            throw PlateError.render("the export failed: \(error)")
        }
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw PlateError.render("the export is not an image")
        }
        return PlateRendered(png: png, width: width, height: height, raw: raw)
    }
}
