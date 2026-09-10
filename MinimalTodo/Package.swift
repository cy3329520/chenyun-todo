// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MinimalTodo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MinimalTodo",
            path: "Sources/MinimalTodo"
        )
    ]
)
