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
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "6.2.0")
    ],
    targets: [
        .target(
            name: "SFBuddyKit",
            dependencies: [
                .product(name: "SFSafeSymbols", package: "SFSafeSymbols")
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