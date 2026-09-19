// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "cat_menubar",
    platforms: [
        .macOS("11.0")
    ],
    products: [
        .executable(name: "cat_menubar", targets: ["cat_menubar"])
    ],
    targets: [
        .target(
            name: "cat_menubar",
            path: "Sources/cat_menubar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
