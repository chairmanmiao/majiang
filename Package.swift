// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MahjongGame",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MahjongGame", targets: ["MahjongGame"])
    ],
    targets: [
        .executableTarget(
            name: "MahjongGame",
            path: "Sources"
        )
    ]
)
