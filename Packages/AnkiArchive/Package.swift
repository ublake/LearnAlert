// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnkiArchive",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "AnkiArchive", targets: ["AnkiArchive"])],
    dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")],
    targets: [
        .target(name: "CZstd", publicHeadersPath: "include", cSettings: [.define("ZSTD_DISABLE_ASM")]),
        .target(name: "AnkiArchive", dependencies: ["ZIPFoundation", "CZstd"], linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "AnkiArchiveTests", dependencies: ["AnkiArchive", "ZIPFoundation"], resources: [.copy("Fixtures")])
    ]
)
