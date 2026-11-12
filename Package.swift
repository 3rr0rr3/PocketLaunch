// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PocketLaunchImport",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")],
    targets: [
        .target(name: "PocketLaunchImport", dependencies: ["ZIPFoundation"], path: "IPACore"),
        .testTarget(name: "PocketLaunchImportTests", dependencies: ["PocketLaunchImport", "ZIPFoundation"], path: "Tests")
    ]
)
