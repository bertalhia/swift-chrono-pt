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

    @Test("Options and recurrence survive a round trip through JSON")
    func codable() throws {
        let options = ChronoPT.Options(allowsPast: true, defaultHour: 9)
        let decodedOptions = try JSONDecoder().decode(
            ChronoPT.Options.self, from: JSONEncoder().encode(options))
        #expect(decodedOptions == options)

        let recurrence = ChronoPT.Recurrence.weekly(on: [.tuesday, .thursday])
        let decoded = try JSONDecoder().decode(
            ChronoPT.Recurrence.self, from: JSONEncoder().encode(recurrence))
        #expect(decoded == recurrence)
    }
}
