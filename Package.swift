// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Foco",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Foco", targets: ["Foco"]),
        .executable(name: "FocoView", targets: ["FocoView"])
    ],
    targets: [
        .executableTarget(
            name: "Foco",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("PDFKit")
            ]
        ),
        .executableTarget(
            name: "FocoView",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("PDFKit")
            ]
        )
    ]
)
