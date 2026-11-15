// swift-tools-version:6.2
import PackageDescription

let package = Package(
  name: "YralApp",
  platforms: [.iOS(.v26), .macOS(.v15)],
  products: [.library(name: "YralApp", targets: ["YralApp"])],
  targets: [
    .target(
      name: "YralApp",
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
    .testTarget(
      name: "YralAppTests",
      dependencies: ["YralApp"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),
  ]
)
