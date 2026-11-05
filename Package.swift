// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacCare",
    defaultLocalization: "fr",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MacCare",
            targets: ["MacCare"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacCare",
            path: "Sources",
            exclude: [
                "Resources/Info.plist",
                "Resources/MacCare.entitlements",
                "Resources/AppIcon.icns",
                "Resources/AppIcon-Preview.png"
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Charts"),
                .linkedFramework("Security"),
                .linkedFramework("CryptoKit"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "UnitTests",
            dependencies: ["MacCare"],
            path: "Tests/UnitTests"
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["MacCare"],
            path: "Tests/IntegrationTests"
        )
    ]
)

