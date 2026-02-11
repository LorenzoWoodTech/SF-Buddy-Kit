// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SFBuddyKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SFBuddyKit",
            targets: ["SFBuddyKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "6.2.0"),
        .package(path: "../LorenzoKit")
    ],
    targets: [
        .target(
            name: "SFBuddyKit",
            dependencies: [
                .product(name: "SFSafeSymbols", package: "SFSafeSymbols"),
                .product(name: "LorenzoKit", package: "LorenzoKit")
            ],
            path: "Sources/SFBuddyKit"
        ),
        .testTarget(
            name: "SFBuddyKitTests",
            dependencies: ["SFBuddyKit"],
            path: "Tests/SFBuddyKitTests"
        )
    ]
)