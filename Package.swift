// swift-tools-version: 6.2
import Foundation
import PackageDescription

/// `release` names an engine's xcframework zip on a GitHub release; `nil` keeps it local-only.
struct Engine {
    let kit: String
    let binary: String
    let release: (version: String, checksum: String)?
    let linkerSettings: [LinkerSetting]
}

let engines = [
    Engine(
        kit: "BergamotKit",
        binary: "BergamotFFI",
        release: ("0.1.0", "a422ef7c7bf69e8b8be209dccef82403b0bbb5ba1c14bc80b6032dd609c4e0ad"),
        linkerSettings: [.linkedLibrary("c++"), .linkedFramework("Accelerate")]
    ),
    Engine(
        kit: "HarperKit",
        binary: "HarperFFI",
        release: ("0.1.0", "4138a0df7e4785644cc5ea7cec6447f5182134b869acb64e1500a3aac4506f4a"),
        linkerSettings: []
    ),
    Engine(
        kit: "LlamaKit",
        binary: "llama",
        release: nil,
        linkerSettings: [.linkedFramework("Metal"), .linkedFramework("Accelerate")]
    ),
]

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

/// A build in `Artifacts/` (scripts/) wins, so engine work needs no release; otherwise the
/// published zip; an engine with neither is left out.
func binaryTarget(of engine: Engine) -> Target? {
    let localPath = "Artifacts/\(engine.binary).xcframework"
    if FileManager.default.fileExists(atPath: packageDirectory.appendingPathComponent(localPath).path) {
        return .binaryTarget(name: engine.binary, path: localPath)
    }
    guard let release = engine.release else { return nil }
    return .binaryTarget(
        name: engine.binary,
        url:
            "https://github.com/mahainc/TextEngines/releases/download/\(release.version)/\(engine.binary).xcframework.zip",
        checksum: release.checksum
    )
}

let availableEngines = engines.compactMap { engine in binaryTarget(of: engine).map { (engine, $0) } }

let package = Package(
    name: "TextEngines",
    platforms: [.iOS(.v17)],
    products: availableEngines.map { engine, _ in .library(name: engine.kit, targets: [engine.kit]) },
    targets: availableEngines.flatMap { engine, binary -> [Target] in
        [
            binary,
            .target(
                name: engine.kit,
                dependencies: [.target(name: engine.binary)],
                linkerSettings: engine.linkerSettings
            ),
            .testTarget(
                name: "\(engine.kit)Tests",
                dependencies: [.target(name: engine.kit)],
                resources: [.copy("Fixtures")]
            ),
        ]
    }
)
