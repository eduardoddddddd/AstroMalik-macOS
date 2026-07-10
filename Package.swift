// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AstroMalik",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AstroMalik", targets: ["AstroMalikApp"]),
        .executable(name: "astromalik-cli", targets: ["astromalik-cli"]),
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
        // Módulo principal compartido por la app GUI y el CLI
        .target(
            name: "AstroMalik",
            dependencies: ["CSwissEph"],
            path: "Sources/AstroMalik",
            resources: [
                .copy("Resources/corpus.db"),
                .copy("Resources/cities_seed.json"),
                .copy("Resources/fixed_stars.json"),
                .copy("Resources/ephe"),
                .copy("Resources/cross_personal_prompt.md"),
                .copy("Resources/rectification_prompt.md"),
                .copy("Resources/Reports"),
                .copy("Reports/Templates"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        // Ejecutable GUI mínimo que arranca el módulo AstroMalik.
        .executableTarget(
            name: "AstroMalikApp",
            dependencies: ["AstroMalik"],
            path: "Sources/AstroMalikApp",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist",
                ]),
            ]
        ),
        // CLI headless para flujos cross-personal desde cron/LaunchAgent
        .executableTarget(
            name: "astromalik-cli",
            dependencies: ["AstroMalik"],
            path: "Sources/AstroMalikCLI"
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
        .testTarget(
            name: "AstroMalikCLITests",
            dependencies: ["astromalik-cli", "AstroMalik"],
            path: "Tests/AstroMalikCLITests"
        ),
    ]
)
