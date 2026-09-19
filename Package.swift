// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "CoreCat",
    platforms: [
        .macOS("11.0")
    ],
    products: [
        .executable(name: "CoreCat", targets: ["CoreCat"])
    ],
    targets: [
        .target(
            name: "CoreCat",
            path: "Sources/CoreCat",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
