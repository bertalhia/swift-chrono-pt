import Foundation
import Testing

@testable import ChronoPT

@Suite("Public API")
struct APITests {
    @Test(
        "The text without the dates",
        arguments: [
            ("comprar pão amanhã no almoço", "comprar pão"),
            (
                "dentista sexta às 14h, reunião dia 30 e ligar pro banco amanhã",
                "dentista, reunião e ligar pro banco"
            ),
            ("almoço de amanhã", "almoço"),
            ("reunião às 14h amanhã", "reunião"),
            ("plantão de segunda a sexta das 9 às 18", "plantão"),
            ("comprar leite", "comprar leite"),
            ("amanhã", ""),
        ])
    func strippingDates(_ example: (text: String, kept: String)) {
        #expect(strip(example.text) == example.kept)
    }

    @Test("A time said apart from the day keeps a span of its own")
    func separateSpans() throws {
        let text = "amanhã de manhã, reunião às 7"
        let found = try #require(ChronoPT.interpret(text, reference: monday, calendar: saoPaulo))
        #expect(text[found.range] == "amanhã de manhã")
        #expect(found.ranges.count == 2)
        #expect(found.ranges.map { String(text[$0]) } == ["amanhã de manhã", "às 7"])

        let single = try #require(interpret("amanhã às 9"))
        #expect(single.ranges.count == 1)
    }

    @Test("A range gives a DateInterval")
    func interval() throws {
        let shift = try #require(interpret("de segunda a sexta das 9 às 18"))
        let interval = try #require(shift.interval)
        #expect(interval.start == shift.start.date)
        #expect(interval.end == shift.end?.date)
        #expect(try #require(interpret("amanhã às 9")).interval == nil)
    }

    @Test("Known components as DateComponents")
    func dateComponents() throws {
        let found = try #require(interpret("25/09"))
        let parts = found.start.dateComponents(in: saoPaulo)
        #expect(parts.day == 25)
        #expect(parts.month == 9)
        #expect(parts.year == nil)
        #expect(found.start.hasDay)
        #expect(found.start.hasTime == false)
        #expect(try #require(interpret("às 9")).start.hasDay == false)
    }

    @Test("An app can build a result of its own")
    func buildingAResult() {
        let start = ChronoPT.PartialDate(date: monday, knownComponents: [.day, .month, .year])
        let match = ChronoPT.Match(range: "x".startIndex..<"x".endIndex, text: "amanhã", start: start)
        #expect(match.ranges == [match.range])
        #expect(match.start.hasDay)
        #expect(match.recurrence == nil)
        #expect(Set([match]).count == 1)
    }

    @Test("A result prints the text and the date")
    func debugDescription() throws {
        let found = try #require(interpret("amanhã às 9"))
        #expect(found.debugDescription.contains("amanhã às 9"))
        #expect(found.debugDescription.contains("2026-09-22"))
    }

    @Test("A parser keeps its calendar and options")
    func parser() throws {
        let parser = ChronoPT.Parser(
            calendar: saoPaulo, options: ChronoPT.Options(allowsPast: true, defaultHour: 9))
        let found = try #require(parser.interpret("paguei ontem", reference: monday))
        #expect(ymd(found.start.date) == [2026, 9, 20])
        #expect(hm(found.start.date) == [9, 0])
        #expect(parser.parse("amanhã e depois de amanhã", reference: monday).count == 2)
        #expect(parser.strippingDates(from: "comprar pão amanhã", reference: monday) == "comprar pão")
        #expect(
            parser.interpret("dentista sexta às 14h", reference: monday) == interpret("dentista sexta às 14h")
        )
    }

    @Test(
        "An hour that does not say morning or evening gives the other reading",
        arguments: [
            ("amanhã às 7", [2026, 9, 22], [19, 0], [2026, 9, 22], [7, 0]),
            ("amanhã às 9", [2026, 9, 22], [9, 0], [2026, 9, 22], [21, 0]),
            ("às 7", [2026, 9, 21], [19, 0], [2026, 9, 22], [7, 0]),
        ])
    func ambiguousHour(_ example: (text: String, day: [Int], time: [Int], otherDay: [Int], otherTime: [Int]))
        throws
    {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
        let other = try #require(found.start.alternative)
        #expect(ymd(other) == example.otherDay)
        #expect(hm(other) == example.otherTime)
    }

    @Test(
        "An hour that says morning or evening has no other reading",
        arguments: [
            "amanhã às 7 da manhã", "amanhã de manhã, às 7", "amanhã às 14h", "amanhã às 7h", "amanhã",
        ])
    func unambiguousHour(_ text: String) throws {
        #expect(try #require(interpret(text)).start.alternative == nil)
    }

    @Test("A recurrence prints the same way every time")
    func stableDescription() throws {
        let found = try #require(interpret("às quartas e segundas às 7h"))
        #expect(found.recurrence?.description == "FREQ=WEEKLY;BYDAY=MO,WE")
        #expect(ChronoPT.Recurrence.daily(every: 15).description == "FREQ=DAILY;INTERVAL=15")
        #expect(found.debugDescription.hasSuffix("repeating FREQ=WEEKLY;BYDAY=MO,WE"))
    }

    @Test("Options and recurrence survive a round trip through JSON")
    func codable() throws {
        let options = ChronoPT.Options(allowsPast: true, defaultHour: 9)
        let decodedOptions = try JSONDecoder().decode(
            ChronoPT.Options.self, from: JSONEncoder().encode(options))
        #expect(decodedOptions == options)

        var recurrence = ChronoPT.Recurrence.weekly(on: [.tuesday, .thursday])
        recurrence.end = .until(monday)
        let decoded = try JSONDecoder().decode(
            ChronoPT.Recurrence.self, from: JSONEncoder().encode(recurrence))
        #expect(decoded == recurrence)
    }
}
