// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pasty",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pasty", targets: ["Pasty"])
    ],
    targets: [
        .executableTarget(
            name: "Pasty",
            path: "Sources/Pasty",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
