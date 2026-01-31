// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DICOMKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "DICOMKit",
            targets: ["DICOMKit"]
        ),
        .library(
            name: "DICOMCore",
            targets: ["DICOMCore"]
        ),
        .library(
            name: "DICOMDictionary",
            targets: ["DICOMDictionary"]
        ),
        .library(
            name: "DICOMNetwork",
            targets: ["DICOMNetwork"]
        ),
        // Example DICOM Viewer application
        .executable(
            name: "DICOMViewer",
            targets: ["DICOMViewer"]
        )
    ],
    targets: [
        .target(
            name: "DICOMCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "DICOMDictionary",
            dependencies: ["DICOMCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "DICOMNetwork",
            dependencies: ["DICOMCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "DICOMKit",
            dependencies: ["DICOMCore", "DICOMDictionary"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        // Example DICOM Viewer Application
        .executableTarget(
            name: "DICOMViewer",
            dependencies: ["DICOMKit", "DICOMNetwork", "DICOMCore"],
            path: "Examples/DICOMViewer/Sources",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DICOMCoreTests",
            dependencies: ["DICOMCore"]
        ),
        .testTarget(
            name: "DICOMDictionaryTests",
            dependencies: ["DICOMDictionary"]
        ),
        .testTarget(
            name: "DICOMKitTests",
            dependencies: ["DICOMKit"]
        ),
        .testTarget(
            name: "DICOMNetworkTests",
            dependencies: ["DICOMNetwork"]
        )
    ]
)
