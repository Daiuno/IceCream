// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "IceCream",
    platforms: [
        .macOS(.v10_12), .iOS(.v11), .tvOS(.v10), .watchOS(.v4)
    ],
    products: [
        .library(
            name: "IceCream",
            targets: ["IceCream"])
    ],
    dependencies: [
        // Patched for Xcode 26.4 (realm-core d8f21f9); switch back when 10.54.7 ships.
        .package(
            url: "https://github.com/Daiuno/realm-swift.git",
            branch: "manicemu"
        )
    ],
    targets: [
        .target(
            name: "IceCream",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-swift"),
            ],
            path: "IceCream",
            sources: ["Classes"])
    ],
    swiftLanguageVersions: [.v5]
)
