import Foundation

/// The plate's face and seal, found where the package's resource bundle was copied: beside the app's resources,
/// beside the executable (a command-line tool, a test bundle), or where `PLATE_RESOURCES` points.
///
/// PIN: never `Bundle.module`. Its accessor ends the process when the bundle is not where the build put it, and an
/// app that links the package and forgot to copy the bundle must get an error it can show, not a crash. The face
/// falls back to the one installed in ~/Library/Fonts; a missing seal is an error that says where it looked.
enum PlateResources {
    static let bundleName = "PlateAgent_PlateAgent.bundle"
    static let fontName = "PlayfairDisplay-Italic-VariableFont_wght.ttf"
    static let markName = "rr-mark.png"

    /// The face and seal as data URLs, so the page fetches nothing.
    static func faces() throws -> PlateKit.Faces {
        let places = directories()
        let font = find(fontName, in: places) ?? installedFont()
        guard let font, let fontData = try? Data(contentsOf: font) else { throw PlateError.resources(tried: places.map(\.path)) }
        guard let mark = find(markName, in: places), let markData = try? Data(contentsOf: mark) else {
            throw PlateError.resources(tried: places.map(\.path))
        }
        return PlateKit.Faces(font: "data:font/ttf;base64," + fontData.base64EncodedString(),
                              mark: "data:image/png;base64," + markData.base64EncodedString())
    }

    /// Where the resources may be, in the order they are looked for.
    static func directories() -> [URL] {
        var places: [URL] = []
        if let override = ProcessInfo.processInfo.environment["PLATE_RESOURCES"], !override.isEmpty {
            places.append(URL(fileURLWithPath: (override as NSString).expandingTildeInPath))
        }
        let main = Bundle.main
        var homes: [URL] = [main.resourceURL, main.bundleURL].compactMap { $0 }
        if let executable = main.executableURL?.resolvingSymlinksInPath().deletingLastPathComponent() {
            homes.append(executable)
            homes.append(executable.deletingLastPathComponent().appendingPathComponent("Resources"))
        }
        homes.append(Bundle(for: Token.self).bundleURL.deletingLastPathComponent())
        for home in homes {
            let bundle = home.appendingPathComponent(bundleName)
            if !places.contains(bundle) { places.append(bundle) }
        }
        return places
    }

    /// `name` inside any of `places`, at whatever depth the bundle keeps it.
    private static func find(_ name: String, in places: [URL]) -> URL? {
        let manager = FileManager.default
        for place in places where manager.fileExists(atPath: place.path) {
            for candidate in [place.appendingPathComponent(name), place.appendingPathComponent("Resources/\(name)"),
                              place.appendingPathComponent("Contents/Resources/\(name)"), place.appendingPathComponent("Contents/Resources/Resources/\(name)")]
            where manager.fileExists(atPath: candidate.path) {
                return candidate
            }
            if let walker = manager.enumerator(at: place, includingPropertiesForKeys: nil) {
                for case let url as URL in walker where url.lastPathComponent == name { return url }
            }
        }
        return nil
    }

    private static func installedFont() -> URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Fonts/\(fontName)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// A class of this module's own, for the bundle its code was loaded from.
    private final class Token {}
}
