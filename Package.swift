// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AstroMalik",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AstroMalik", targets: ["AstroMalik"]),
    ],
    dependencies: [],   // Sin dependencias externas — SQLite3 del sistema
    targets: [
        // Swiss Ephemeris C library
        .target(
            name: "CSwissEph",
            path: "Sources/CSwissEph",
            exclude: ["include/module.modulemap"],
            publicHeadersPath: "include",
            cSettings: [
                .define("JAVAME", to: "0"),
            ]
        ),
        // Aplicación principal
        .executableTarget(
            name: "AstroMalik",
            dependencies: ["CSwissEph"],
            path: "Sources/AstroMalik",
            resources: [
                .copy("Resources/corpus.db"),
                .copy("Resources/cities_seed.json"),
                .copy("Resources/ephe"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist",
                ]),
            ]
        ),
        // Tests
        .testTarget(
            name: "AstroMalikTests",
            dependencies: ["AstroMalik"],
            path: "Tests/AstroMalikTests",
            exclude: ["PRIMARY_DIRECTIONS_TESTS.md"],
            resources: [
                .process("PrimaryDirectionsGolden.json"),
            ]
        ),
    ]
)
