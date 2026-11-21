import BergamotKit
import Foundation
import Testing

private let modelDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("../../Models/bergamot-enes")
    .standardizedFileURL

private let modelsPresent = FileManager.default.fileExists(atPath: modelDirectory.path)

@Suite(.enabled(if: modelsPresent, "Models/bergamot-enes is absent; run scripts/fetch-models.sh"))
struct BergamotEngineTests {
    @Test func translatesEnglishToSpanishAndReportsTimings() async throws {
        let clock = ContinuousClock()

        var engine: BergamotEngine?
        let load = try await clock.measure { engine = try BergamotEngine(modelDirectory: modelDirectory) }
        let loaded = try #require(engine)

        var spanish = ""
        let first = try await clock.measure { spanish = try await loaded.translate("The museum opens at nine.") }
        print("bergamot: \"The museum opens at nine.\" -> \"\(spanish)\"")
        #expect(spanish.lowercased().contains("museo"))

        let sentence = "The guided tour of the old cathedral starts near the main entrance every afternoon."
        let warmRuns = 20
        var warm = Duration.zero
        var warmOutput = ""
        for _ in 0..<warmRuns {
            warm += try await clock.measure { warmOutput = try await loaded.translate(sentence) }
        }
        print("bergamot: \"\(sentence)\" -> \"\(warmOutput)\"")
        #expect(warmOutput.lowercased().contains("catedral"))
        let warmMean = warm / warmRuns
        print("bergamot timings: load \(load), first \(first), warm mean \(warmMean)")
        #expect(load < .seconds(30))
        #expect(warmMean < .seconds(2))
    }

    @Test func emptyTextTranslatesToEmptyText() async throws {
        let engine = try BergamotEngine(modelDirectory: modelDirectory)
        #expect(try await engine.translate("").isEmpty)
    }

    @Test func missingDirectoryThrowsUnreadableDirectory() {
        let directory = "/nonexistent"
        #expect {
            try BergamotEngine(modelDirectory: URL(fileURLWithPath: directory))
        } throws: { error in
            guard case .unreadableModelDirectory(directory: directory, reason: _) = error as? BergamotError else {
                return false
            }
            return true
        }
    }
}

extension ContinuousClock {
    fileprivate func measure(_ body: () async throws -> Void) async rethrows -> Duration {
        let start = now
        try await body()
        return now - start
    }
}
