// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ChibiRay",
    products: [
        .library(
            name: "ChibiRay",
            targets: ["ChibiRay"]),
    ],
    targets: [
        .executableTarget(
            name: "chibi-ray",
            dependencies: ["ChibiRay"]
        ),
        .target(name: "ChibiRay"),
    ]
)
