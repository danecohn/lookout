// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Lookout", platforms: [.macOS(.v14)], products: [.executable(name: "Lookout", targets: ["Lookout"])], targets: [.target(name: "LookoutCore"), .executableTarget(name: "Lookout", dependencies: ["LookoutCore"]), .testTarget(name: "LookoutCoreTests", dependencies: ["LookoutCore"])], swiftLanguageVersions: [.v5])
