// swift-tools-version:6.0
// PlateAgent: an editorial architecture plate of a project's flow, drafted by the host's model, laid out and
// measured in WebKit, and written as a PNG at 2x, as a Granite agent package. An app that links it finds the
// `plate` agent through Granite's roster, with nothing listed by hand.

import PackageDescription

let package = Package(
    name: "PlateAgent",
    // WebKit's WebPage renders and measures the plate in-process, with no window: macOS 26.
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "PlateAgent", targets: ["PlateAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "PlateAgent",
            dependencies: [.product(name: "GraniteAgents", package: "Granite")],
            // The plate's face (Playfair Display Italic, under the OFL) and its seal, so a plate renders the
            // same on any Mac.
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "PlateAgentTests",
            dependencies: ["PlateAgent", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
