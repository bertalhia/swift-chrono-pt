import Foundation
import Testing

@testable import ChronoPT

/// Cases an audit found answering with the wrong date.
@Suite("Audit")
struct AuditTests {
    @Test(
        "A time from now never takes over a day said in the same text",
        arguments: [
            ("consulta dia 30, sair daqui a 20 minutos", [2026, 9, 30]),
            ("reunião amanhã, ligar daqui a 2 horas", [2026, 9, 22]),
            ("comprar pão amanhã, sair em meia hora", [2026, 9, 22]),
        ])
    func fromNowKeepsItsPlace(_ example: (text: String, day: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
    }

    @Test("Both the day and the time from now come out of parse")
    func fromNowIsItsOwnResult() {
        let found = parse("consulta dia 30, sair daqui a 20 minutos")
        #expect(found.count == 2)
        #expect(ymd(found[0].start.date) == [2026, 9, 30])
        #expect(ymd(found[1].start.date) == [2026, 9, 21])
        #expect(hm(found[1].start.date) == [10, 20])
    }

    @Test(
        "A weekday and its date, separated by a hyphen, is that date",
        arguments: [
            ("sáb - 3/10", [2026, 10, 3]),
            ("segunda - 12/10/2026", [2026, 10, 12]),
            ("sáb 3/10", [2026, 10, 3]),
        ])
    func weekdayHyphenDate(_ example: (text: String, day: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(found.end == nil)
    }

    @Test("Normalization keeps one character for each character")
    func normalizationKeepsLength() {
        let marks = ["\u{064B}", "\u{0301}", "\u{363}", "\u{0e31}", "\u{20e3}"]
        let leads = ["\n", "\r", "\t", " ", "a", ".", "🇧🇷"]
        for lead in leads {
            for mark in marks {
                let text = "reunião\(lead)\(mark)amanhã às 9"
                #expect(TextSource(text).normalized.count == text.count, "\(text.debugDescription)")
            }
        }
    }

    @Test("A combining mark after a line break keeps the range aligned")
    func combiningMarkAfterLineBreak() throws {
        let text = "reunião\n\u{064B}amanhã às 9"
        let found = try #require(interpret(text))
        #expect(found.text == "amanhã às 9")
    }

    @Test("Midnight to midnight is a whole day")
    func midnightToMidnight() throws {
        let found = try #require(interpret("amanhã da meia-noite à meia-noite"))
        #expect(ymd(found.start.date) == [2026, 9, 23])
        #expect(hm(found.start.date) == [0, 0])
        let end = try #require(found.end)
        #expect(ymd(end.date) == [2026, 9, 24])
        #expect(hm(end.date) == [0, 0])
    }

    @Test("Digits that are not ASCII are not a time")
    func nonASCIIDigits() {
        #expect(interpret("10:٣٠") == nil)
        #expect(interpret("às ٣") == nil)
    }
}
