import Foundation
import HarperKit
import Testing

struct HarperEngineTests {
    let engine = HarperEngine()

    /// harper-core 3.2.0 has no rule for "This are"; a change here means its rules changed.
    @Test func leavesThisAreATestUnchanged() {
        #expect(engine.corrected("This are a test.") == "This are a test.")
    }

    @Test func fixesSubjectVerbAgreementAndArticle() {
        #expect(engine.corrected("She have a apple.") == "She has an apple.")
        #expect(engine.corrected("He go to school yesterday.") == "He goes to school yesterday.")
    }

    @Test func mapsOffsetsPastNonASCIIText() {
        let text = "Café 😀: I has a apple."
        let lints = engine.lints(text)
        #expect(lints.compactMap { $0.range(in: text).map { String(text[$0]) } } == ["has", "a"])
        #expect(engine.corrected(text) == "Café 😀: I have an apple.")
    }

    @Test func correctsAParagraphWellWithinALiveFrameBudget() {
        let paragraph = """
            Yesterday the café owner told me that she have a apple tree behind the shop, \
            and every morning she pick the ripest fruit before the first customers arrives.
            """
        let clock = ContinuousClock()
        var corrected = ""
        let first = clock.measure { corrected = engine.corrected(paragraph) }
        let warm = clock.measure { for _ in 0..<100 { _ = engine.corrected(paragraph) } } / 100
        print("Harper: first call \(first), warm mean \(warm)")
        #expect(corrected.contains("an apple tree"))
        #expect(corrected.contains("she picks the ripest"))
        #expect(first < .seconds(5))
        #expect(warm < .milliseconds(50))
    }
}
