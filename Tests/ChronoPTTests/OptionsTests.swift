import Foundation
import Testing

@testable import ChronoPT

@Suite("Options")
struct OptionsTests {
    static let past = ChronoPT.Options(allowsPast: true)

    @Test(
        "Past dates need allowsPast",
        arguments: [
            ("pagar ontem", [2026, 9, 20]),
            ("anteontem", [2026, 9, 19]),
            ("antes de ontem", [2026, 9, 19]),
            ("sexta passada", [2026, 9, 18]),
            ("na sexta-feira passada", [2026, 9, 18]),
            ("na última sexta", [2026, 9, 18]),
            ("segunda passada", [2026, 9, 14]),
            ("há 2 dias", [2026, 9, 19]),
            ("3 dias atrás", [2026, 9, 18]),
            ("faz uma semana", [2026, 9, 14]),
            ("há um mês", [2026, 8, 21]),
            ("há 3 anos", [2023, 9, 21]),
        ])
    func pastDay(_ example: (text: String, day: [Int])) throws {
        #expect(interpret(example.text) == nil)
        let found = try #require(interpret(example.text, options: Self.past))
        #expect(ymd(found.start.date) == example.day)
        #expect(found.start.hasTime == false)
    }

    @Test(
        "Past periods run from their first to their last day",
        arguments: [
            ("semana passada", [2026, 9, 14], [2026, 9, 20]),
            ("no mês passado", [2026, 8, 1], [2026, 8, 31]),
            ("ano passado", [2025, 1, 1], [2025, 12, 31]),
            ("de ontem até sexta", [2026, 9, 20], [2026, 9, 25]),
            ("fim de semana passado", [2026, 9, 19], [2026, 9, 20]),
        ])
    func pastPeriod(_ example: (text: String, start: [Int], end: [Int])) throws {
        #expect(interpret(example.text) == nil)
        let found = try #require(interpret(example.text, options: Self.past))
        #expect(ymd(found.start.date) == example.start)
        #expect(ymd(found.end?.date) == example.end)
    }

    @Test(
        "Past times need allowsPast",
        arguments: [
            ("ontem à noite", [2026, 9, 20], [19, 0]),
            ("há 2 horas", [2026, 9, 21], [8, 0]),
            ("20 minutos atrás", [2026, 9, 21], [9, 40]),
            ("sexta passada às 10", [2026, 9, 18], [10, 0]),
        ])
    func pastTime(_ example: (text: String, day: [Int], time: [Int])) throws {
        #expect(interpret(example.text) == nil)
        let found = try #require(interpret(example.text, options: Self.past))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
    }

    @Test("Without allowsPast, a past day never reads as a future one")
    func pastWordsBlockTheFuture() {
        #expect(interpret("reunião sexta passada às 10") == nil)
        #expect(interpret("na última sexta às 14h") == nil)
        #expect(parse("ontem à noite e amanhã cedo").map(\.text) == ["amanhã cedo"])
    }

    @Test("allowsPast leaves future dates alone")
    func futureWithPast() throws {
        let found = try #require(interpret("amanhã às 9", options: Self.past))
        #expect(ymd(found.start.date) == [2026, 9, 22])
        #expect(hm(found.start.date) == [9, 0])
    }

    @Test("defaultHour sets the time of a day with no time")
    func defaultHour() throws {
        let options = ChronoPT.Options(defaultHour: 9)
        let day = try #require(interpret("pagar amanhã", options: options))
        #expect(hm(day.start.date) == [9, 0])
        #expect(day.start.hasTime == false)
        let week = try #require(interpret("semana que vem", options: options))
        #expect(hm(try #require(week.end?.date)) == [9, 0])
        let clock = try #require(interpret("amanhã às 15h", options: options))
        #expect(hm(clock.start.date) == [15, 0])
    }

    @Test("defaultHour stays between 0 and 23")
    func defaultHourBounds() throws {
        #expect(ChronoPT.Options(defaultHour: 30).defaultHour == 23)
        #expect(ChronoPT.Options(defaultHour: -1).defaultHour == 0)
        let found = try #require(interpret("amanhã", options: ChronoPT.Options(defaultHour: 30)))
        #expect(hm(found.start.date) == [23, 0])
    }

    static let moments = ChronoPT.Options(moments: [
        "no treino": 7, "na consulta": 14, "Na Aula": 19, "no jogo": 25,
    ])

    @Test(
        "An app's own moments read like the built-in ones",
        arguments: [
            ("amanhã no treino", [2026, 9, 22], [7, 0]),
            ("na consulta", [2026, 9, 21], [14, 0]),
            ("sexta na aula", [2026, 9, 25], [19, 0]),
            ("amanhã na áula", [2026, 9, 22], [19, 0]),
        ])
    func moments(_ example: (text: String, day: [Int], time: [Int])) throws {
        let found = try #require(interpret(example.text, options: Self.moments))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
    }

    @Test("A moment with an hour outside the day is ignored")
    func momentOutsideTheDay() throws {
        let found = try #require(interpret("amanhã no jogo", options: Self.moments))
        #expect(!found.start.hasTime)
    }

    @Test("An app's moment wins over a built-in one written the same way")
    func momentOverridesTable() throws {
        let found = try #require(
            interpret("amanhã no almoço", options: ChronoPT.Options(moments: ["no almoço": 13])))
        #expect(hm(found.start.date) == [13, 0])
    }

    @Test("Options saved before moments existed still decode")
    func decodesWithoutMoments() throws {
        let saved = Data(#"{"allowsPast":true,"hour":9}"#.utf8)
        let options = try JSONDecoder().decode(ChronoPT.Options.self, from: saved)
        #expect(options == ChronoPT.Options(allowsPast: true, defaultHour: 9))
    }
}
