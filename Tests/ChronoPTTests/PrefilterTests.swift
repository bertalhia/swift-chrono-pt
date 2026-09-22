import Foundation
import Testing

@testable import ChronoPT

/// Rules skip their regex when the text holds none of the words it needs. A
/// word missing from a rule's list would lose matches without a sound, so
/// every text here is parsed both ways and has to come out the same.
@Suite("Skipping rules that cannot match")
struct PrefilterTests {
    /// Fragments from every kind of expression the parser reads, plus noise.
    static let fragments: [String] = {
        let readme = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let table = ((try? String(contentsOf: readme, encoding: .utf8)) ?? "")
            .split(separator: "\n")
            .filter { $0.hasPrefix("| ") && !$0.hasPrefix("| Kind") }
            .flatMap { $0.split(separator: "|").dropFirst().first?.components(separatedBy: ", ") ?? [] }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return table + [
            "comprar pão", "reunião", "com o time", "e", "de", "a", ",", "às", "até", "entre", "-", "para",
            "dia", "semana", "mês", "ano", "que vem", "passada", "todo", "toda", "cada", "em", "há", "atrás",
            "2", "10", "15", "25/09", "14h", "9", "quinze", "vinte e três", "natal", "útil", "meio-dia",
            "segunda", "sexta", "sáb", "6ª feira", "outubro", "dez", "da noite", "de manhã", "no almoço",
            "2026-10-15T14:30", "2026-10-15T14:30:00Z", "2026-10-15T14:30:00+01:00", "10 AM",
        ]
    }()

    @Test("Parsing with and without skipping gives the same results", arguments: 0..<600)
    func sameResults(_ seed: Int) {
        var generator = SeededGenerator(seed: UInt64(seed) &+ 7_919)
        let count = Int.random(in: 1...7, using: &generator)
        let text = (0..<count).map { _ in Self.fragments.randomElement(using: &generator)! }.joined(
            separator: " ")
        for options in [ChronoPT.Options(), ChronoPT.Options(allowsPast: true)] {
            let skipping = Context(
                text: text, reference: monday, calendar: saoPaulo, options: options, skipsRules: true)
            let running = Context(
                text: text, reference: monday, calendar: saoPaulo, options: options, skipsRules: false)
            #expect(ChronoPT.parse(skipping) == ChronoPT.parse(running), "\(text)")
            #expect(ChronoPT.interpret(skipping) == ChronoPT.interpret(running), "\(text)")
        }
    }

    @Test("Every README example parses the same both ways")
    func readmeExamples() {
        for text in Self.fragments {
            let skipping = Context(
                text: text, reference: monday, calendar: saoPaulo, options: .init(allowsPast: true),
                skipsRules: true)
            let running = Context(
                text: text, reference: monday, calendar: saoPaulo, options: .init(allowsPast: true),
                skipsRules: false)
            #expect(ChronoPT.interpret(skipping) == ChronoPT.interpret(running), "\(text)")
        }
    }
}
