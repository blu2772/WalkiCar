// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WalkiCar",
  platforms: [
    .iOS(.v16)
  ],
  products: [
    .library(
      name: "WalkiCar",
      targets: ["WalkiCar"]),
  ],
  dependencies: [
    .package(url: "https://github.com/livekit/client-sdk-swift", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "WalkiCar",
      dependencies: [
        .product(name: "LiveKit", package: "client-sdk-swift"),
      ]),
    .testTarget(
      name: "WalkiCarTests",
      dependencies: ["WalkiCar"]),
  ]
)
