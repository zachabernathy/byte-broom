// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ByteBroom",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ByteBroomCore"),
        .executableTarget(name: "ByteBroom", dependencies: ["ByteBroomCore"]),
        .testTarget(name: "ByteBroomCoreTests", dependencies: ["ByteBroomCore"]),
    ],
    swiftLanguageModes: [.v5]
)
