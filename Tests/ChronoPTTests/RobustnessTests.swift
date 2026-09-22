import Foundation
import Testing

@testable import ChronoPT

@Suite("Robustness")
struct RobustnessTests {
    /// Pieces that look like dates and times, plus accents, emoji, line breaks
    /// and lone combining marks, which change how characters group.
    static let pieces = [
        "amanhã", "às", "9", "14h", "10:30", "dia", "30", "25/09", "2026-10-15", "de", "outubro",
        "sexta", "que vem", "no almoço", "à noite", "quinze para as oito", "vinte e três",
        "daqui", "2", "horas", "por dia", "no natal", "semana", "mês", "e meia", "meio-dia",
        "ÀS", "Amanhã,", "(sexta)", "—", "🇧🇷", "👍🏽", "e\u{301}", "\u{301}", "\n", "\r\n", "\t",
        "ß", "ﬁ", "İ", "٣", "𝟗", "  ", ",", ".", "/", ":", "-", "\u{064B}", "\u{0e31}", "\u{363}",
    ]

    @Test("Random text never crashes, and every range points into the input", arguments: 0..<200)
    func randomText(_ seed: Int) throws {
        var generator = SeededGenerator(seed: UInt64(seed))
        let count = Int.random(in: 1...12, using: &generator)
        let text = (0..<count).map { _ in Self.pieces.randomElement(using: &generator)! }
            .joined(separator: Bool.random(using: &generator) ? " " : "")

        // The old check compared the range against text taken from that same
        // range, so it could never fail. This one holds the real invariant.
        #expect(TextSource(text).normalized.count == text.count, "\(text.debugDescription)")

        for result in parse(text) {
            #expect(text[result.range] == result.text[...], "\(text.debugDescription)")
        }
        if let result = interpret(text) {
            #expect(text[result.range] == result.text[...], "\(text.debugDescription)")
        }
    }

    @Test("Parsing from many tasks at once gives the same results as one at a time")
    func concurrentParsing() async {
        let texts = Self.pieces.indices.map { index in
            Self.pieces[index...].prefix(6).joined(separator: " ")
        }
        let serial = texts.map { parse($0).map(\.text) }
        let concurrent = await withTaskGroup(of: (Int, [String]).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask { (index, parse(text).map(\.text)) }
            }
            var results = Array(repeating: [String](), count: texts.count)
            for await (index, found) in group { results[index] = found }
            return results
        }
        #expect(concurrent == serial)
    }

    /// Parsing used to be cubic: the pair loops asked questions about gaps
    /// that scanned the rest of the text, so 2.4 KB of repeated weekdays took
    /// 13 seconds. The ceiling is loose on purpose; a return to cubic misses it
    /// by two orders of magnitude.
    @Test(
        "A long text parses in well under a second",
        arguments: [
            String(repeating: "segunda ", count: 300),
            String(repeating: "amanha ", count: 300),
            String(repeating: "1/1 ", count: 300),
            String(repeating: "reunião dia 12 às 14h com o time sobre o lançamento, ", count: 120),
        ])
    func longTextIsFast(_ text: String) {
        let start = ContinuousClock.now
        _ = parse(text)
        #expect(start.duration(to: .now) < .seconds(3), "\(text.count) characters")
    }

    @Test("A lone combining mark after a line break keeps positions aligned")
    func combiningMarkAfterLineBreak() throws {
        let text = "\n\u{301}amanhã às 9"
        let found = try #require(interpret(text))
        #expect(text[found.range] == "amanhã às 9")
    }
    @Test(
        "A mark next to a line break keeps every position",
        arguments: ["\n\u{093E}amanhã às 9", "\u{0D4E}\namanhã às 9", "\r\u{093E}amanhã às 9"])
    func markNextToLineBreak(_ text: String) throws {
        let found = try #require(parse(text).first)
        #expect(found.text == "amanhã às 9")
        #expect(String(text[found.range]) == found.text)
    }

    @Test("strippingDates keeps a mark next to a line break")
    func stripKeepsMark() {
        #expect(strip("\u{0D4E}\nreunião amanhã às 9 com o time") == "\u{0D4E}\nreunião com o time")
    }

    @Test("strippingDates is linear in a run of whitespace")
    func stripWhitespaceRun() {
        let text = String(repeating: " \n", count: 4000) + "amanhã"
        let clock = ContinuousClock()
        let elapsed = clock.measure { _ = strip(text) }
        #expect(elapsed < .seconds(1))
    }

    @Test("Ten minutes before a midnight named as 12 is the day before")
    func minutesBeforeTwelve() throws {
        #expect(hm(try #require(interpret("dez para as 12 da manhã")).start.date) == [23, 50])
    }

    @Test(
        "Joining days stays close to linear on repeated dates",
        arguments: [
            String(repeating: "amanhã ", count: 2000), String(repeating: "sexta 25, ", count: 1000),
            String(repeating: "toda segunda ", count: 1000),
            String(repeating: "de segunda a sexta ", count: 500),
            String(repeating: "2 dias antes do natal ", count: 500),
        ])
    func repeatedDates(_ text: String) {
        // Quadratic joining took seconds on each of these; now tens of
        // milliseconds in a debug build.
        let elapsed = ContinuousClock().measure { _ = parse(text) }
        #expect(elapsed < .seconds(1))
    }

    @Test("Counting many business days works each year's holidays out once")
    func manyBusinessDays() throws {
        let clock = ContinuousClock()
        var found: ChronoPT.Match?
        let elapsed = clock.measure { found = interpret("prazo em 999 dias úteis") }
        #expect(ymd(try #require(found).start.date) == [2030, 9, 19])
        #expect(elapsed < .seconds(1))
    }

    @Test("A thread keeps no compiled set once its parse is done")
    func regexPool() {
        final class Result: @unchecked Sendable { var kept = true }
        let result = Result()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            _ = parse("reunião sexta às 14h, pagar dia 10")
            result.kept = RegexCache.threadKeepsSet
            done.signal()
        }
        thread.start()
        done.wait()
        #expect(!result.kept)
        #expect(RegexCache.idleCount >= 1)
    }
}

/// SplitMix64: the same seed gives the same text on every run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

}
