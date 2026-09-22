import Foundation
import Testing

@testable import ChronoPT

@Suite("Recurrence")
struct RecurrenceTests {
    @Test(
        "Repeating notes give the next time and how they repeat",
        arguments: [
            (
                "tirar o lixo toda terça às 20h", [2026, 9, 22], [20, 0],
                ChronoPT.Recurrence.weekly(on: [.tuesday])
            ),
            ("reunião toda segunda às 9", [2026, 9, 28], [9, 0], .weekly(on: [.monday])),
            ("toda segunda às 18h", [2026, 9, 21], [18, 0], .weekly(on: [.monday])),
            ("todas as sextas às 19h", [2026, 9, 25], [19, 0], .weekly(on: [.friday])),
            ("toda 2ª feira às 9h", [2026, 9, 28], [9, 0], .weekly(on: [.monday])),
            (
                "academia às segundas e quartas às 7h", [2026, 9, 23], [7, 0],
                .weekly(on: [.monday, .wednesday])
            ),
            (
                "inglês nas terças e quintas às 19h", [2026, 9, 22], [19, 0],
                .weekly(on: [.tuesday, .thursday])
            ),
            ("todo dia às 8", [2026, 9, 22], [8, 0], .daily()),
            ("tomar remédio todos os dias às 22h", [2026, 9, 21], [22, 0], .daily()),
        ])
    func withTime(_ example: (text: String, day: [Int], time: [Int], recurrence: ChronoPT.Recurrence)) throws
    {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
        #expect(found.recurrence == example.recurrence)
    }

    @Test(
        "Repeating days with no time",
        arguments: [
            ("todo sábado", [2026, 9, 26], ChronoPT.Recurrence.weekly(on: [.saturday])),
            ("regar as plantas diariamente", [2026, 9, 21], .daily()),
            ("pagar aluguel todo dia 5", [2026, 10, 5], .monthly(day: 5)),
            ("todo mês no dia 10", [2026, 10, 10], .monthly(day: 10)),
            ("pagar no dia 10 de cada mês", [2026, 10, 10], .monthly(day: 10)),
            ("no dia 5 de todo mês", [2026, 10, 5], .monthly(day: 5)),
        ])
    func dayOnly(_ example: (text: String, day: [Int], recurrence: ChronoPT.Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(found.start.hasTime == false)
        #expect(found.recurrence == example.recurrence)
    }

    @Test(
        "Repeating every few days, weeks or months",
        arguments: [
            (
                "regar as plantas a cada 15 dias", [2026, 9, 21],
                ChronoPT.Recurrence.daily(every: 15)
            ),
            ("reunião de 2 em 2 semanas às 10h", [2026, 9, 21], .weekly(every: 2)),
            ("toda semana", [2026, 9, 21], .weekly()),
            ("todo mês", [2026, 9, 21], .monthly()),
            ("mensalmente", [2026, 9, 21], .monthly()),
            ("semanalmente", [2026, 9, 21], .weekly()),
        ])
    func interval(_ example: (text: String, day: [Int], recurrence: ChronoPT.Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(found.recurrence == example.recurrence)
    }

    @Test(
        "Intervals of hours and minutes count from now",
        arguments: [
            ("tomar de 8 em 8 horas", [18, 0], ChronoPT.Recurrence.hourly(every: 8)),
            ("a cada 6 horas", [16, 0], .hourly(every: 6)),
            ("de hora em hora", [11, 0], .hourly()),
            ("a cada 30 minutos", [10, 30], .minutely(every: 30)),
        ])
    func hourInterval(_ example: (text: String, time: [Int], recurrence: ChronoPT.Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == [2026, 9, 21])
        #expect(hm(found.start.date) == example.time)
        #expect(found.start.hasTime)
        #expect(found.recurrence == example.recurrence)
    }

    @Test("Different counts are not an interval")
    func mismatchedInterval() throws {
        #expect(try #require(interpret("de 2 em 3 semanas")).recurrence == nil)
    }

    @Test("A single day does not repeat", arguments: ["amanhã", "na segunda", "sexta às 10", "dia 5"])
    func single(_ text: String) throws {
        #expect(try #require(interpret(text)).recurrence == nil)
    }

    @Test("Plural weekday words need \"às\", \"nas\" or \"todas as\"")
    func pluralWithoutPreposition() {
        #expect(interpret("segundas intenções") == nil)
    }

    @Test(
        "Rates, alternate days, weekdays in the month and yearly dates",
        arguments: [
            (
                "tomar 3x ao dia", [2026, 9, 21],
                ChronoPT.Recurrence(frequency: .daily, rate: .init(count: 3, per: .daily))
            ),
            (
                "duas vezes por semana", [2026, 9, 21],
                ChronoPT.Recurrence(frequency: .weekly, rate: .init(count: 2, per: .weekly))
            ),
            // Once a week is every week.
            ("uma vez por semana", [2026, 9, 21], .weekly()),
            ("dia sim, dia não", [2026, 9, 21], .daily(every: 2)),
            ("semana sim, semana não", [2026, 9, 21], .weekly(every: 2)),
            (
                "toda última sexta do mês", [2026, 9, 25],
                ChronoPT.Recurrence(frequency: .monthly, weekdays: [.nth(-1, .friday)])
            ),
            (
                "toda primeira segunda do mês", [2026, 10, 5],
                ChronoPT.Recurrence(frequency: .monthly, weekdays: [.nth(1, .monday)])
            ),
            (
                "todo 2º sábado do mês", [2026, 10, 10],
                ChronoPT.Recurrence(frequency: .monthly, weekdays: [.nth(2, .saturday)])
            ),
            ("todo ano", [2026, 9, 21], .yearly()),
            ("a cada 2 anos", [2026, 9, 21], .yearly(every: 2)),
            ("todo ano em julho", [2027, 7, 1], ChronoPT.Recurrence(frequency: .yearly, months: [7])),
            (
                "todo 25 de dezembro", [2026, 12, 25],
                ChronoPT.Recurrence(frequency: .yearly, daysOfMonth: [25], months: [12])
            ),
            (
                "todo dia 25 de dezembro", [2026, 12, 25],
                ChronoPT.Recurrence(frequency: .yearly, daysOfMonth: [25], months: [12])
            ),
        ] as [(String, [Int], ChronoPT.Recurrence)])
    func moreRules(_ example: (text: String, day: [Int], recurrence: ChronoPT.Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(found.recurrence == example.recurrence)
    }

    @Test(
        "Where a repeating day stops",
        arguments: [
            // The end of the last day, in UTC: 23:59:59 in São Paulo.
            ("aula toda terça até dezembro", "FREQ=WEEKLY;BYDAY=TU;UNTIL=20270101T025959Z"),
            ("toda terça às 20h até dezembro", "FREQ=WEEKLY;BYDAY=TU;UNTIL=20270101T025959Z"),
            ("toda terça até o fim do ano", "FREQ=WEEKLY;BYDAY=TU;UNTIL=20270101T025959Z"),
            ("todo dia até 30/09", "FREQ=DAILY;UNTIL=20261001T025959Z"),
            // Ten days from the first, today.
            ("todo dia por 10 dias", "FREQ=DAILY;UNTIL=20261001T025959Z"),
            // 8:00 has passed, so the first is tomorrow.
            ("todo dia às 8 por 10 dias", "FREQ=DAILY;UNTIL=20261002T025959Z"),
            ("toda segunda, 5 vezes", "FREQ=WEEKLY;BYDAY=MO;COUNT=5"),
        ])
    func end(_ example: (text: String, rrule: String)) throws {
        let found = try #require(interpret(example.text))
        #expect(found.recurrence?.rrule == example.rrule)
        #expect(found.text == example.text.replacingOccurrences(of: "aula ", with: ""))
    }

    @Test("A count with no repeating day, or a rate, is not an end")
    func notAnEnd() throws {
        #expect(interpret("tomar 3 vezes") == nil)
        #expect(try #require(interpret("toda terça, 3 vezes ao dia")).recurrence?.end == nil)
    }

    @Test(
        "A count after \"todo dia\" is not a day of the month",
        arguments: [
            "estudar inglês todo dia 30 minutos", "fazer todos os dias 10 flexões",
            "todo dia 2 horas de piano",
        ])
    func countAfterEveryDay(_ text: String) throws {
        #expect(try #require(interpret(text)).recurrence == .daily())
    }

    @Test("\"todo dia 1º\" is monthly")
    func firstOfEveryMonth() throws {
        #expect(try #require(interpret("todo dia 1º")).recurrence == .monthly(day: 1))
    }

    @Test(
        "The end of a repeating day in the month under way",
        arguments: [
            (
                "toda terça até setembro", reference(2026, 9, 21),
                "FREQ=WEEKLY;BYDAY=TU;UNTIL=20261001T025959Z"
            ),
            (
                "toda terça até dezembro", reference(2026, 12, 5),
                "FREQ=WEEKLY;BYDAY=TU;UNTIL=20270101T025959Z"
            ),
        ])
    func endInMonthUnderWay(_ example: (text: String, reference: Date, rrule: String)) throws {
        #expect(
            try #require(interpret(example.text, reference: example.reference)).recurrence?.rrule
                == example.rrule)
    }

    @Test(
        "A fifth weekday of the month is found however far it is",
        arguments: [
            ("toda quinta quarta do mês", reference(2026, 1, 5), [2026, 4, 29]),
            ("todo quinto sábado do mês", reference(2026, 2, 1), [2026, 5, 30]),
        ])
    func fifthWeekday(_ example: (text: String, reference: Date, day: [Int])) throws {
        #expect(
            ymd(try #require(interpret(example.text, reference: example.reference)).start.date) == example.day
        )
    }

    @Test("Several times on a repeating day are one rule")
    func severalTimesOfDay() throws {
        let found = try #require(interpret("remédio às 8h e às 20h todo dia"))
        #expect(found.text == "às 8h e às 20h todo dia")
        // 8:00 has passed: the next is 20:00 today.
        #expect(ymd(found.start.date) == [2026, 9, 21])
        #expect(hm(found.start.date) == [20, 0])
        #expect(found.recurrence?.timesOfDay == [8, ChronoPT.TimeOfDay(hour: 20)!])
        #expect(found.recurrence?.rrule == "FREQ=DAILY;BYHOUR=8,20;BYMINUTE=0")
        #expect(parse("remédio às 8h e às 20h todo dia").count == 1)
    }

    @Test("A rate inside a weekly rule")
    func rateInsideWeekly() throws {
        let found = try #require(interpret("toda terça, 3 vezes ao dia"))
        #expect(found.recurrence?.weekdays == [.every(.tuesday)])
        #expect(found.recurrence?.rate == .init(count: 3, per: .daily))
        #expect(found.recurrence?.description == "FREQ=WEEKLY;BYDAY=TU (3 per day)")
    }
}
