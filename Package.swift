// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacDial",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacDial",
            path: "Sources/MacDial",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
