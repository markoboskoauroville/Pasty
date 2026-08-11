// swift-tools-version: 5.9
import PackageDescription

// Deliberately 5.9, not 6.0. The 6.0 manifest API uses `swiftLanguageModes`,
// which does not exist on older toolchains, and the manifest is compiled by
// whatever Swift the user has. A Command Line Tools install that lags Xcode by
// a release fails to even parse a 6.0 manifest. 5.9 parses everywhere and the
// default language mode below 6.0 is already Swift 5, which is what this code
// expects, so nothing is lost.
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
    ]
)
