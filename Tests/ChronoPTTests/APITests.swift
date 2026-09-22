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

    @Test("A time range gives its DateInterval, and a single moment none")
    func interval() throws {
        let shift = try #require(interpret("de segunda a sexta das 9 às 18"))
        let interval = try #require(shift.dateInterval)
        #expect(interval.start == shift.start.date)
        #expect(interval.end == shift.end?.date)
        #expect(try #require(interpret("amanhã às 9")).dateInterval == nil)
    }

    @Test(
        "A date with no time covers whole days",
        arguments: [
            ("amanhã", [2026, 9, 22], [2026, 9, 23]),
            ("semana que vem", [2026, 9, 28], [2026, 10, 5]),
            ("em outubro", [2026, 10, 1], [2026, 11, 1]),
            ("amanhã o dia todo", [2026, 9, 22], [2026, 9, 23]),
        ])
    func wholeDays(_ example: (text: String, start: [Int], end: [Int])) throws {
        let found = try #require(interpret(example.text))
        let interval = try #require(found.dateInterval)
        #expect(ymd(interval.start) == example.start)
        #expect(hm(interval.start) == [0, 0])
        #expect(ymd(interval.end) == example.end)
        #expect(hm(interval.end) == [0, 0])
    }

    @Test("A time zone the text named stays with the date")
    func namedTimeZone() throws {
        var utc = saoPaulo
        utc.timeZone = TimeZone(identifier: "UTC")!
        let found = try #require(ChronoPT.interpret("amanhã às 15h BRT", reference: monday, calendar: utc))
        #expect(found.start.timeZone == TimeZone(identifier: "America/Sao_Paulo"))
        let parts = found.start.dateComponents(in: utc)
        #expect(parts.hour == 15)
        #expect(parts.timeZone == TimeZone(identifier: "America/Sao_Paulo"))
        #expect(try #require(interpret("amanhã às 15h")).start.timeZone == nil)
        #expect(
            try #require(interpret("2026-10-15T14:30:00+01:00")).start.timeZone
                == TimeZone(secondsFromGMT: 3600))
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

    @Test("interpret leaves a time next to another day to that day")
    func timeOfAnotherDay() throws {
        let found = try #require(interpret("amanhã comprar pão, sexta às 14h dentista"))
        #expect(ymd(found.start.date) == [2026, 9, 22])
        #expect(!found.start.hasTime)
        #expect(
            !(try #require(interpret("hoje à noite jantar, amanhã às 8 reunião")).start.knownComponents
                .contains(.minute)))
    }

    @Test(
        "strippingDates takes the article and the punctuation the date leaves",
        arguments: [
            ("reunião para o dia 15", "reunião"), ("entregar até o dia 10", "entregar"),
            ("comprar pão, amanhã.", "comprar pão."),
            ("reunião — amanhã às 10h — sala 4", "reunião — sala 4"),
        ])
    func strippingLeftovers(_ example: (text: String, stripped: String)) {
        #expect(strip(example.text) == example.stripped)
    }

    @Test("Recurrence has a stable JSON form")
    func recurrenceJSON() throws {
        let rule = ChronoPT.Recurrence(
            frequency: .monthly, weekdays: [.nth(-1, .friday), .nth(1, .monday)],
            timesOfDay: [ChronoPT.TimeOfDay(hour: 20)!, 8], end: .count(5))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(rule), as: UTF8.self)
        #expect(
            json
                == #"{"daysOfMonth":[],"end":{"count":5},"frequency":"monthly","interval":1,"months":[],"#
                + #""timesOfDay":[{"hour":8,"minute":0},{"hour":20,"minute":0}],"#
                + #""weekdays":[{"ordinal":1,"weekday":"mon"},{"ordinal":-1,"weekday":"fri"}]}"#)
        #expect(try JSONDecoder().decode(ChronoPT.Recurrence.self, from: Data(json.utf8)) == rule)
        #expect(rule.rrule == "FREQ=MONTHLY;BYDAY=1MO,-1FR;BYHOUR=8,20;BYMINUTE=0;COUNT=5")
    }

    @Test(
        "Recurrence refuses values no rule can hold",
        arguments: [
            #"{"frequency":"daily","interval":0}"#, #"{"frequency":"yearly","months":[13]}"#,
            #"{"frequency":"monthly","daysOfMonth":[0]}"#, #"{"frequency":"daily","end":{"count":0}}"#,
            #"{"frequency":"daily","timesOfDay":[{"hour":24}]}"#,
        ])
    func recurrenceRefusesInvalid(_ json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ChronoPT.Recurrence.self, from: Data(json.utf8))
        }
    }

    @Test("An interval is at least 1")
    func intervalClamps() {
        var rule = ChronoPT.Recurrence.daily()
        rule.interval = -3
        #expect(rule.interval == 1)
        #expect(ChronoPT.Recurrence.daily(every: 0).interval == 1)
    }

    @Test("Options write defaultHour, and read what 0.x wrote")
    func optionsJSON() throws {
        let options = ChronoPT.Options(defaultHour: 9, moments: ["no treino": 7])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(
            String(decoding: try encoder.encode(options), as: UTF8.self)
                == #"{"allowsPast":false,"defaultHour":9,"moments":{"no treino":{"hour":7,"minute":0}}}"#)
        let old = #"{"allowsPast":true,"hour":9,"moments":{"no treino":7}}"#
        #expect(
            try JSONDecoder().decode(ChronoPT.Options.self, from: Data(old.utf8))
                == ChronoPT.Options(allowsPast: true, defaultHour: 9, moments: ["no treino": 7]))
    }

    @Test(
        "strippingDates takes the phrase that opens a date",
        arguments: [
            ("férias a partir de amanhã", "férias"), ("entregar antes de 15/11", "entregar"),
            ("ligar antes das 10", "ligar"), ("sair depois das 18h", "sair"), ("sair dps das 18h", "sair"),
            ("pagar no próximo dia 15", "pagar"), ("comprar p/ amanhã", "comprar"),
            ("descansar nesse fds", "descansar"), ("ficar a partir do dia 10", "ficar"),
            // "partir" alone is a verb.
            ("vou partir amanhã", "vou partir"),
        ])
    func strippingOpeningPhrases(_ example: (text: String, stripped: String)) {
        #expect(strip(example.text) == example.stripped)
    }

    @Test(
        "strippingDates takes the brackets around a date",
        arguments: [
            ("reunião às 15h (BRT)", "reunião"), ("prova (28/09)", "prova"),
            ("call às 9 (horário de Brasília) com o time", "call com o time"), ("(UTC-03:00) 10h", ""),
        ])
    func strippingBrackets(_ example: (text: String, stripped: String)) {
        #expect(strip(example.text) == example.stripped)
    }

    @Test(
        "A match says when the text was rough",
        arguments: [
            ("umas 8", true), ("por volta de 15h", true), ("lá pelas 3", true), ("daqui a pouco", true),
            ("mais tarde", true), ("meados de outubro", true), ("daqui uns 10 dias", true),
            ("amanhã às 9", false),
            ("pela manhã", false), ("pelas próximas 2 semanas", false),
        ])
    func approximate(_ example: (text: String, isApproximate: Bool)) throws {
        #expect(try #require(interpret(example.text)).isApproximate == example.isApproximate)
    }

    @Test("strippingDates takes the matches an app already has")
    func strippingFromMatches() {
        let note = "comprar pão amanhã no almoço"
        #expect(ChronoPT.strippingDates(parse(note), from: note) == "comprar pão")
        #expect(ChronoPT.strippingDates([], from: note) == note)
    }

    @Test("An all-day rule writes its end as a date")
    func allDayUntil() {
        let rule = ChronoPT.Recurrence(frequency: .weekly, weekdays: [.every(.tuesday)], end: .until(monday))
        #expect(rule.rrule == "FREQ=WEEKLY;BYDAY=TU;UNTIL=20260921T130000Z")
        #expect(rule.rrule(allDayIn: saoPaulo) == "FREQ=WEEKLY;BYDAY=TU;UNTIL=20260921")
    }

    #if canImport(Darwin)
        @Test("A rule becomes Foundation's RecurrenceRule")
        func foundationRule() throws {
            guard #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) else { return }
            let rule = try #require(interpret("toda última sexta do mês até dezembro")).recurrence
            let foundation = try #require(rule).recurrenceRule(in: saoPaulo)
            #expect(foundation.frequency == .monthly)
            #expect(foundation.weekdays == [.nth(-1, .friday)])
            let dates = Array(
                foundation.recurrences(
                    of: reference(2026, 9, 25), in: reference(2026, 9, 1)..<reference(2027, 1, 31)))
            #expect(dates.map(ymd) == [[2026, 9, 25], [2026, 10, 30], [2026, 11, 27], [2026, 12, 25]])
        }
    #endif
}
