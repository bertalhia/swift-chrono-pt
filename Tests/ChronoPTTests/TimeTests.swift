import Foundation
import Testing

@testable import ChronoPT

@Suite("Times")
struct TimeTests {
    @Test(
        "Clock times, parts of the day and meals set a time",
        arguments: [
            ("comprar coca cola amanha no almoco", 12, 0),
            ("amanhã na janta", 19, 0),
            ("amanhã no jantar", 19, 0),
            ("amanhã depois do almoço", 14, 0),
            ("amanhã antes do almoço", 11, 0),
            ("amanhã na hora da janta", 19, 0),
            ("amanhã depois da janta", 21, 0),
            ("amanhã antes de dormir", 22, 0),
            ("amanhã cedo", 7, 0),
            ("amanhã logo cedo", 7, 0),
            ("amanhã de manhã cedo", 7, 0),
            ("amanhã de madrugada", 5, 0),
            ("amanhã de manhã", 9, 0),
            ("amanhã no café da manhã", 8, 0),
            ("amanhã ao meio-dia", 12, 0),
            ("amanhã ao meio-dia e meia", 12, 30),
            ("amanhã à tarde", 15, 0),
            ("amanhã de tarde", 15, 0),
            ("amanhã no lanche da tarde", 16, 0),
            ("amanhã à tardinha", 18, 0),
            ("amanhã no fim da tarde", 18, 0),
            ("amanhã à noite", 19, 0),
            ("amanhã tarde da noite", 23, 0),
            ("amanhã às 9", 9, 0),
            ("amanhã às 7 e meia", 19, 30),
            ("amanhã às 7 da manhã", 7, 0),
            ("amanhã de manhã às 7", 7, 0),
            ("amanhã às sete", 19, 0),
            ("amanhã às sete da noite", 19, 0),
            ("amanhã às dez e meia", 10, 30),
            ("amanhã às 3 da tarde", 15, 0),
            ("amanhã às 7h", 7, 0),
            ("amanhã às 9h30", 9, 30),
            ("amanhã 14h", 14, 0),
            ("amanhã às 20:15", 20, 15),
            ("amanha as 11 hrs", 11, 0),
            ("amanhã às oito e quarenta e cinco", 8, 45),
            ("amanhã às quinze para as oito", 7, 45),
            ("amanhã quinze para as oito", 7, 45),
            ("amanhã vinte para as dez", 9, 40),
            ("amanhã vinte e cinco pras 9", 8, 35),
            ("amanhã quinze para as sete da noite", 18, 45),
            ("amanhã quinze para a uma", 12, 45),
            ("amanhã 10 minutos para as 3 da tarde", 14, 50),
            ("amanhã quinze para o meio-dia", 11, 45),
            ("amanhã dez para a meia-noite", 23, 50),
            ("amanhã às vinte e duas horas", 22, 0),
            ("amanhã às treze horas", 13, 0),
            ("amanhã às dezoito e trinta", 18, 30),
            ("amanhã às oito e trinta e cinco", 8, 35),
            ("amanhã às dezenove e quinze", 19, 15),
            ("amanhã às vinte e uma e quarenta", 21, 40),
            ("amanhã às 15:30h", 15, 30),
            ("amanhã às 15h30m", 15, 30),
            ("amanhã às 15h30min", 15, 30),
            ("amanhã às 15h00", 15, 0),
            ("amanhã pelas 21h00", 21, 0),
            ("amanhã ao pequeno-almoço", 8, 0),
            ("amanhã ao jantar", 19, 0),
            ("amanhã à hora de almoço", 12, 0),
            ("amanhã à hora do jantar", 19, 0),
            ("amanhã ao fim da tarde", 18, 0),
            ("amanhã ao final da tarde", 18, 0),
            ("amanhã ao fim do dia", 18, 0),
            ("amanhã dps do almoço", 14, 0),
            ("amn às 11", 11, 0),
            ("amanhã de manhã bem cedo", 7, 0),
            ("amanhã de manhã bem cedinho", 7, 0),
            ("amanhã no meio dia", 12, 0),
            ("amanhã até o fim do dia", 18, 0),
            ("amanhã até o final do expediente", 18, 0),
            ("amanhã até o fim da manhã", 11, 0),
            ("amanhã no comecinho da tarde", 13, 0),
            ("amanhã de madruga", 5, 0),
            ("amanhã na boquinha da noite", 18, 30),
            ("amanhã de tardezinha", 18, 0),
            ("amanhã no finalzinho do dia", 18, 0),
        ])
    func time(_ example: (text: String, hour: Int, minute: Int)) throws {
        let found = try #require(interpret(example.text))
        #expect(found.start.hasTime)
        #expect(ymd(found.start.date) == [2026, 9, 22])
        #expect(hm(found.start.date) == [example.hour, example.minute])
    }

    @Test("Midnight of a day is the start of the next day")
    func midnight() throws {
        let today = try #require(interpret("hoje à meia-noite"))
        #expect(ymd(today.start.date) == [2026, 9, 22])
        #expect(hm(today.start.date) == [0, 0])
        let tomorrow = try #require(interpret("amanhã à meia-noite"))
        #expect(ymd(tomorrow.start.date) == [2026, 9, 23])
        let spoken = try #require(interpret("às 12 da noite"))
        #expect(ymd(spoken.start.date) == [2026, 9, 22])
        #expect(hm(spoken.start.date) == [0, 0])
    }

    @Test("With no day, it is today at that time, or tomorrow if it has passed")
    func noDay() throws {
        let before = try #require(interpret("comprar pão no almoço"))
        #expect(before.start.hasTime)
        #expect(ymd(before.start.date) == [2026, 9, 21])
        #expect(hm(before.start.date) == [12, 0])
        #expect(before.text == "no almoço")

        let afternoon = monday.addingTimeInterval(3 * 3600)
        let after = try #require(interpret("comprar pão no almoço", reference: afternoon))
        #expect(ymd(after.start.date) == [2026, 9, 22])
    }

    @Test(
        "A time with no day, written several ways",
        arguments: [
            ("ligar pro João de tarde", 15),
            ("tomar remédio à noite", 19),
            ("tomar remédio ao acordar", 7),
            ("estudar depois do trabalho", 18),
            ("ligar às sete da noite", 19),
            ("reunião às 19h", 19),
            ("3 da tarde", 15),
        ])
    func noDayForms(_ example: (text: String, hour: Int)) throws {
        let found = try #require(interpret(example.text))
        #expect(found.start.hasTime)
        #expect(hm(found.start.date).first == example.hour)
        #expect(found.start.date > monday)
    }

    @Test("\"Daqui a\" counts from now")
    func fromNow() throws {
        #expect(try #require(interpret("daqui 2 horas")).start.date == monday.addingTimeInterval(2 * 3600))
        #expect(try #require(interpret("em meia hora")).start.date == monday.addingTimeInterval(30 * 60))
        #expect(
            try #require(interpret("daqui a 20 minutos")).start.date == monday.addingTimeInterval(20 * 60))
    }

    @Test(
        "A bare number, a duration and a lone \"cedo\" are not times",
        arguments: [
            "estudar por 2 horas",
            "comprar uma caneta",
            "o jogo virou de 3 pra 1",
            "comprar dezesseis ovos",
            "comprar de 2 a 3 kg",
            "chegar cedo",
        ])
    func notATime(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test(
        "A number of hours per day is a duration, not a time",
        arguments: [
            "trabalhar 8h por dia",
            "estudar 2 horas por semana",
            "dormir 8h por noite",
            "dormir 8 horas diárias",
        ])
    func hoursPerDay(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test(
        "A part of the day next to the day settles a clock time said later",
        arguments: [
            ("amanhã de manhã, reunião às 7", 7, 0),
            ("amanhã à noite, jantar às 8", 20, 0),
            ("amanhã no almoço, reunião às 13h", 13, 0),
            ("amanhã de madrugada, voo às 3 e meia", 3, 30),
        ])
    func partOfDayThenClock(_ example: (text: String, hour: Int, minute: Int)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == [2026, 9, 22])
        #expect(hm(found.start.date) == [example.hour, example.minute])
    }

    @Test("A clock time in the other half of the day leaves the part of the day alone")
    func partOfDayThenOtherHalf() throws {
        let found = try #require(interpret("amanhã de manhã ligar pro João, jantar às 19h"))
        #expect(hm(found.start.date) == [9, 0])
        #expect(found.text == "amanhã de manhã")
    }

    @Test(
        "A time range sets the start and the end",
        arguments: [
            ("amanhã das 14h às 16h", [14, 0], [16, 0]),
            ("amanhã das 9 às 11", [9, 0], [11, 0]),
            ("amanhã de 14h a 16h", [14, 0], [16, 0]),
            ("amanhã entre 10 e 11h", [10, 0], [11, 0]),
            ("amanhã entre as 10 e as 11", [10, 0], [11, 0]),
            ("amanhã das 14h30 até as 15h", [14, 30], [15, 0]),
            ("amanhã das 7 às 9 da noite", [19, 0], [21, 0]),
            ("amanhã das 7 às 9 da manhã", [7, 0], [9, 0]),
            ("amanhã das 7 às 9", [19, 0], [21, 0]),
            ("amanhã das 10 às 2", [10, 0], [14, 0]),
            ("amanhã de 2 a 3 da tarde", [14, 0], [15, 0]),
            ("amanhã à noite, das 8 às 10", [20, 0], [22, 0]),
            ("reunião amanhã 10 às 12", [10, 0], [12, 0]),
            ("amanhã 9-10h", [9, 0], [10, 0]),
            ("amanhã 14-16h", [14, 0], [16, 0]),
        ])
    func timeRange(_ example: (text: String, start: [Int], end: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(found.start.hasTime)
        #expect(ymd(found.start.date) == [2026, 9, 22])
        #expect(hm(found.start.date) == example.start)
        let end = try #require(found.end?.date)
        #expect(ymd(end) == [2026, 9, 22])
        #expect(hm(end) == example.end)
    }

    @Test(
        "A deadline counts from now",
        arguments: [
            ("em até 48 horas", [2026, 9, 23], [10, 0]),
            ("em até 30 minutos", [2026, 9, 21], [10, 30]),
            ("no prazo de 2 horas", [2026, 9, 21], [12, 0]),
        ])
    func deadline(_ example: (text: String, day: [Int], time: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
    }

    @Test(
        "English clock times and seconds",
        arguments: [
            ("amanhã às 9am", [9, 0]),
            ("amanhã 3pm", [15, 0]),
            ("amanhã 7:30 pm", [19, 30]),
            ("amanhã 10 AM", [10, 0]),
            ("amanhã 12pm", [12, 0]),
            ("amanhã às 14:30:15", [14, 30]),
        ])
    func englishClock(_ example: (text: String, time: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == [2026, 9, 22])
        #expect(hm(found.start.date) == example.time)
        #expect(found.start.alternative == nil)
    }

    @Test(
        "ISO date and time, with or without an offset",
        arguments: [
            ("2026-10-15T14:30", [2026, 10, 15], [14, 30]),
            ("2026-10-15 14:30:00", [2026, 10, 15], [14, 30]),
            ("prazo 2026-10-15T14:30:00-03:00", [2026, 10, 15], [14, 30]),
            ("2026-10-15T14:30:00Z", [2026, 10, 15], [11, 30]),
            ("2026-10-15T14:30:00+01:00", [2026, 10, 15], [10, 30]),
        ])
    func isoDateTime(_ example: (text: String, day: [Int], time: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
        #expect(found.start.hasTime)
    }

    @Test(
        "Vague times count from now",
        arguments: [
            ("me lembra mais tarde", [12, 0]),
            ("daqui a pouco", [10, 30]),
            ("daqui a pouquinho", [10, 30]),
            ("já já", [10, 30]),
            ("logo mais", [12, 0]),
            ("hoje mais tarde", [12, 0]),
            ("mais tarde hoje", [12, 0]),
        ])
    func vagueTime(_ example: (text: String, time: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == [2026, 9, 21])
        #expect(hm(found.start.date) == example.time)
    }

    @Test("\"Agora\" alone is not a date, and \"à tarde\" is still the afternoon")
    func agoraIsNotADate() throws {
        #expect(interpret("agora vou comprar pão") == nil)
        #expect(hm(try #require(interpret("amanhã à tarde")).start.date) == [15, 0])
    }

    @Test("A time from now joins a day only when it lands on that day")
    func fromNowJoinsItsOwnDay() throws {
        let today = try #require(interpret("hoje, daqui a 2 horas"))
        #expect(hm(today.start.date) == [12, 0])
        #expect(today.text == "hoje, daqui a 2 horas")
        let other = try #require(interpret("reunião amanhã, ligar daqui a 2 horas"))
        #expect(ymd(other.start.date) == [2026, 9, 22])
    }

    @Test("A time range past midnight ends the next day")
    func overnightRange() throws {
        let found = try #require(interpret("amanhã das 22h às 2h"))
        #expect(ymd(found.start.date) == [2026, 9, 22])
        #expect(hm(found.start.date) == [22, 0])
        let end = try #require(found.end?.date)
        #expect(ymd(end) == [2026, 9, 23])
        #expect(hm(end) == [2, 0])
    }

    @Test("A time range with no day is today, or tomorrow if it has started")
    func rangeWithoutDay() throws {
        let later = try #require(interpret("reunião das 14h às 16h"))
        #expect(ymd(later.start.date) == [2026, 9, 21])
        #expect(hm(try #require(later.end?.date)) == [16, 0])
        let passed = try #require(interpret("academia das 8h às 9h"))
        #expect(ymd(passed.start.date) == [2026, 9, 22])
        #expect(ymd(passed.end?.date) == [2026, 9, 22])
        #expect(hm(try #require(passed.end?.date)) == [9, 0])
    }

    @Test(
        "Two times joined by \"e\" without \"entre\" are not a range",
        arguments: [
            "amanhã às 9 e às 10",
            "amanhã de 9h e 10h",
        ])
    func twoTimesAreNotARange(_ text: String) throws {
        let found = try #require(interpret(text))
        #expect(hm(found.start.date) == [9, 0])
        #expect(found.end == nil)
    }

    @Test("\"Para a janta\" is a purpose, not a time")
    func purposeIsNotATime() throws {
        #expect(interpret("comprar para a janta") == nil)
        let found = try #require(interpret("comprar para a janta amanhã"))
        #expect(found.start.hasTime == false)
        #expect(found.text == "amanhã")
    }

    @Test("A part of the day also applies to periods and days of the month")
    func partOfDayWithPeriod() throws {
        let nextWeek = try #require(interpret("semana que vem de manhã"))
        #expect(nextWeek.start.hasTime)
        #expect(ymd(nextWeek.start.date) == [2026, 9, 28])
        #expect(hm(nextWeek.start.date) == [9, 0])
        #expect(ymd(nextWeek.end?.date) == [2026, 10, 4])

        let day30 = try #require(interpret("dia 30 à noite"))
        #expect(ymd(day30.start.date) == [2026, 9, 30])
        #expect(hm(day30.start.date) == [19, 0])
    }

    @Test(
        "A whole part of the day is a range of hours",
        arguments: [
            ("amanhã a manhã toda", [2026, 9, 22], [6, 0], [2026, 9, 22], [12, 0]),
            ("amanhã toda a manhã", [2026, 9, 22], [6, 0], [2026, 9, 22], [12, 0]),
            ("sexta a tarde inteira", [2026, 9, 25], [12, 0], [2026, 9, 25], [18, 0]),
            ("hoje a noite toda", [2026, 9, 21], [18, 0], [2026, 9, 22], [0, 0]),
            ("sábado a madrugada toda", [2026, 9, 26], [0, 0], [2026, 9, 26], [6, 0]),
            // No day: today, since noon has not come yet.
            ("a tarde toda", [2026, 9, 21], [12, 0], [2026, 9, 21], [18, 0]),
        ])
    func wholePartOfTheDay(
        _ example: (text: String, day: [Int], start: [Int], endDay: [Int], end: [Int])
    ) throws {
        let found = try #require(interpret(example.text))
        #expect(found.text == example.text)
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.start)
        let end = try #require(found.end?.date)
        #expect(ymd(end) == example.endDay)
        #expect(hm(end) == example.end)
        #expect(!found.isAllDay)
    }

    @Test(
        "The whole day has no hour",
        arguments: [
            ("amanhã o dia todo", [2026, 9, 22]),
            ("sexta o dia inteiro", [2026, 9, 25]),
            ("sexta, dia inteiro", [2026, 9, 25]),
            ("amanhã, evento de dia inteiro", [2026, 9, 22]),
        ])
    func wholeDay(_ example: (text: String, day: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(found.isAllDay)
        #expect(!found.start.hasTime)
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == [12, 0])
    }

    @Test("The whole day of a range or a repeating day")
    func wholeDayOfARange() throws {
        let week = try #require(interpret("de segunda a sexta o dia todo"))
        #expect(week.isAllDay)
        #expect(ymd(week.start.date) == [2026, 9, 28])
        #expect(ymd(week.end?.date) == [2026, 10, 2])
        #expect(week.end?.hasTime == false)

        let weekly = try #require(interpret("toda terça o dia todo"))
        #expect(weekly.isAllDay)
        #expect(weekly.recurrence == .weekly(on: [.tuesday]))
    }

    @Test(
        "The whole day needs a day", arguments: ["o dia todo", "choveu o dia todo", "evento de dia inteiro"])
    func wholeDayNeedsADay(_ text: String) {
        #expect(interpret(text) == nil)
        #expect(parse(text).isEmpty)
    }

    static let lisbon: Calendar = {
        var calendar = saoPaulo
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }()

    @Test(
        "A time zone in the text decides the instant, in any calendar",
        arguments: [
            // Expected in São Paulo time.
            ("amanhã às 15h BRT", [2026, 9, 22], [15, 0]),
            ("amanhã às 10h UTC", [2026, 9, 22], [7, 0]),
            ("amanhã 16h GMT-3", [2026, 9, 22], [16, 0]),
            ("amanhã 16h GMT+1", [2026, 9, 22], [12, 0]),
            ("amanhã 10h UTC+05:30", [2026, 9, 22], [1, 30]),
            ("amanhã às 9 horário de Brasília", [2026, 9, 22], [9, 0]),
            ("amanhã 14h no horário de SP", [2026, 9, 22], [14, 0]),
            ("amanhã 15h EST", [2026, 9, 22], [16, 0]),
        ])
    func zoneInText(_ example: (text: String, day: [Int], time: [Int])) throws {
        for calendar in [saoPaulo, Self.lisbon] {
            let found = try #require(ChronoPT.interpret(example.text, reference: monday, calendar: calendar))
            #expect(found.text == example.text)
            #expect(ymd(found.start.date) == example.day)
            #expect(hm(found.start.date) == example.time)
            #expect(found.start.knownComponents.contains(.timeZone))
        }
    }

    @Test("A time with a zone and no day is the next time it comes")
    func zoneWithoutDay() throws {
        // 9:00 in Brasília is 13:00 in Lisbon, and it is 14:00 there.
        let found = try #require(
            ChronoPT.interpret("às 9 horário de Brasília", reference: monday, calendar: Self.lisbon))
        #expect(ymd(found.start.date) == [2026, 9, 22])
        #expect(hm(found.start.date) == [9, 0])
    }

    @Test("A time range in a zone")
    func zoneRange() throws {
        let found = try #require(interpret("das 14h às 16h UTC"))
        #expect(hm(found.start.date) == [11, 0])
        #expect(hm(try #require(found.end?.date)) == [13, 0])
    }

    @Test("A zone alone, or a phrase that is not one, is no time", arguments: ["horário de Brasília", "UTC"])
    func zoneAlone(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("\"horário de verão\" is not a zone")
    func summerTime() throws {
        let found = try #require(interpret("amanhã às 9 horário de verão"))
        #expect(found.text == "amanhã às 9")
        #expect(!found.start.knownComponents.contains(.timeZone))
    }

    @Test(
        "An approximate hour reads like an exact one",
        arguments: [
            // 8 is morning, like "às 8"; 8:00 has passed, so it is tomorrow.
            ("chego umas 8", [2026, 9, 22], [8, 0], "umas 8"),
            ("umas 8 da noite", [2026, 9, 21], [20, 0], "umas 8 da noite"),
            ("umas 8 e meia", [2026, 9, 22], [8, 30], "umas 8 e meia"),
            ("umas 3h", [2026, 9, 22], [3, 0], "umas 3h"),
            ("amanhã umas 8, pode ser", [2026, 9, 22], [8, 0], "amanhã umas 8"),
            ("lá pras 3", [2026, 9, 21], [15, 0], "lá pras 3"),
            ("pras 3 da tarde", [2026, 9, 21], [15, 0], "pras 3 da tarde"),
            ("por volta de 15h", [2026, 9, 21], [15, 0], "por volta de 15h"),
            ("em torno de 10h", [2026, 9, 22], [10, 0], "em torno de 10h"),
            ("em torno das 10", [2026, 9, 22], [10, 0], "em torno das 10"),
            ("perto do meio-dia", [2026, 9, 21], [12, 0], "perto do meio-dia"),
            ("perto de meio-dia", [2026, 9, 21], [12, 0], "perto de meio-dia"),
        ])
    func approximateHour(_ example: (text: String, day: [Int], time: [Int], match: String)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
        #expect(found.text == example.match)
    }

    @Test(
        "An approximate count is not a time",
        arguments: [
            "comprei umas 8 laranjas", "estudar umas 2 horas", "por umas 2h", "vou pras 3 lojas",
            "por volta de 10 pessoas", "cerca de 10 pessoas",
        ])
    func approximateCount(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test(
        "An approximate amount of time from now",
        arguments: [
            ("chego em uns 15 minutos", [10, 15], "em uns 15 minutos"),
            ("daqui umas 2 horas", [12, 0], "daqui umas 2 horas"),
        ])
    func approximateFromNow(_ example: (text: String, time: [Int], match: String)) throws {
        let found = try #require(interpret(example.text))
        #expect(hm(found.start.date) == example.time)
        #expect(found.text == example.match)
    }

    @Test(
        "A number a day holds, or a label, does not open a time range",
        arguments: [
            ("reunião dia 10 às 14h", [2026, 10, 10], [14, 0], "dia 10 às 14h"),
            ("dia 5 às 9", [2026, 10, 5], [9, 0], "dia 5 às 9"),
            ("sexta dia 9 às 14h", [2026, 10, 9], [14, 0], "sexta dia 9 às 14h"),
            ("reunião na sala 12 às 15h", [2026, 9, 21], [15, 0], "às 15h"),
            ("turma 8 às 10h", [2026, 9, 22], [10, 0], "às 10h"),
        ])
    func dayNumberIsNotAnHour(_ example: (text: String, day: [Int], time: [Int], match: String)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
        #expect(found.end == nil)
        #expect(found.text == example.match)
    }

    @Test(
        "A bare number still opens a range where a time can start",
        arguments: [
            "reunião amanhã 10 às 12", "10 às 12 reunião", "reunião: 10 às 12", "reunião de 10 às 12",
        ])
    func bareRangeWhereATimeStarts(_ text: String) throws {
        let found = try #require(interpret(text))
        #expect(hm(found.start.date) == [10, 0])
        #expect(hm(try #require(found.end?.date)) == [12, 0])
    }

    @Test("A range of days keeps its own numbers")
    func dayRangeWithTime() throws {
        let found = try #require(interpret("do dia 10 ao dia 15 às 9h"))
        #expect(ymd(found.start.date) == [2026, 10, 10])
        #expect(hm(found.start.date) == [9, 0])
        #expect(ymd(found.end?.date) == [2026, 10, 15])
    }

    @Test(
        "From now, with short units and minutes after the hours",
        arguments: [
            ("daqui a 1h", [11, 0]), ("daqui a 2hrs", [12, 0]), ("dentro de 2h", [12, 0]),
            ("daqui a 1 h", [11, 0]),
            ("em 1h", [11, 0]), ("daqui 1h30", [11, 30]), ("daqui a 30min", [10, 30]),
            ("daqui a 2 horas e meia", [12, 30]), ("daqui a uma hora e meia", [11, 30]),
            ("daqui a 1 hora e 15 minutos", [11, 15]), ("em 1 hora e 30 minutos", [11, 30]),
        ])
    func fromNowUnits(_ example: (text: String, time: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == [2026, 9, 21])
        #expect(hm(found.start.date) == example.time)
        #expect(found.text == example.text)
    }

    @Test("Minutes need their unit after the hours")
    func minutesNeedAUnit() throws {
        #expect(try #require(interpret("daqui a 2 horas e 3 tarefas")).text == "daqui a 2 horas")
    }

    @Test("Short units back in time", arguments: ["há 2h", "2h atrás"])
    func agoUnits(_ text: String) throws {
        let found = try #require(interpret(text, options: ChronoPT.Options(allowsPast: true)))
        #expect(hm(found.start.date) == [8, 0])
        #expect(found.text == text)
    }

    @Test(
        "Two clock times are two times unless a range joins them",
        arguments: [
            ("às 10h, às 15h", ["às 10h", "às 15h"]),
            ("Reunião às 10h. Às 15h dentista.", ["às 10h", "Às 15h"]),
            ("das 9 às 12h e das 14h às 18h", ["das 9 às 12h", "das 14h às 18h"]),
            ("às 9h de manhã e às 9h da noite", ["às 9h de manhã", "às 9h da noite"]),
        ])
    func twoClockTimes(_ example: (text: String, matches: [String])) {
        #expect(parse(example.text).map(\.text) == example.matches)
    }

    @Test("A day and a time in different sentences stay apart")
    func sentenceBreak() {
        #expect(parse("Comprar pão amanhã. Às 15h dentista.").map(\.text) == ["amanhã", "Às 15h"])
        // A full stop before a lowercase word is an abbreviation.
        #expect(parse("seg. às 10").map(\.text) == ["seg. às 10"])
    }

    @Test(
        "am and pm after \"às\"",
        arguments: [
            ("às 7:30 pm", [21], [19, 30]), ("às 9 pm", [21], [21, 0]), ("amanhã às 8 pm", [22], [20, 0]),
            ("às 11 am", [21], [11, 0]),
        ])
    func meridiemAfterAs(_ example: (text: String, day: [Int], time: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == [2026, 9] + example.day)
        #expect(hm(found.start.date) == example.time)
        #expect(found.start.alternative == nil)
        #expect(found.text == example.text)
    }

    @Test(
        "\"as\" and \"das\" without an accent before a count are articles",
        arguments: [
            "buscar as 2 crianças na escola", "comprar as 2 pizzas", "escolher uma das 3 opções",
            "vou a uma reunião",
        ])
    func articleBeforeCount(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test(
        "\"às\" and \"à\" are always a time",
        arguments: [
            ("reunião às 3 com o João", [15, 0]), ("à uma", [13, 0]), ("à uma e meia", [13, 30]),
            ("chego as 3", [15, 0]), ("a uma hora", [13, 0]),
        ])
    func accentedAs(_ example: (text: String, time: [Int])) throws {
        #expect(hm(try #require(interpret(example.text)).start.date) == example.time)
    }

    @Test(
        "Hours after \"de\" are how long, unless a range closes them",
        arguments: ["reunião de 2h", "treino de 1h", "aula de 1h30", "filme de 3h"])
    func lengthAfterDe(_ text: String) {
        #expect(interpret(text) == nil)
        #expect(interpret(text + " amanhã")?.start.hasTime == false)
    }

    @Test("A range after \"de\" is still a range", arguments: ["de 9h às 11h", "de 9h a 11h", "de 10h-11h"])
    func rangeAfterDe(_ text: String) throws {
        #expect(try #require(interpret(text)).end != nil)
    }

    @Test(
        "Written hour units are the 24-hour clock",
        arguments: [
            ("às 9:30hrs", [9, 30]), ("às 15:30hrs", [15, 30]), ("às 3 h", [3, 0]), ("às 3 hs", [3, 0]),
            // Said, not written: the afternoon.
            ("às 3 horas", [15, 0]),
        ])
    func writtenUnits(_ example: (text: String, time: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(hm(found.start.date) == example.time)
        #expect(found.text == example.text)
    }

    @Test("A line break with a carriage return ends a phrase")
    func carriageReturn() throws {
        #expect(hm(try #require(interpret("chego umas 8\r\nlevar bolo")).start.date) == [8, 0])
        #expect(ymd(try #require(interpret("sexta, 25\r\nlevar bolo")).start.date) == [2026, 9, 25])
    }

    @Test("On a single day, the reading that has not passed wins")
    func unpassedReading() throws {
        let tonight = try #require(interpret("hoje às 9"))
        #expect(hm(tonight.start.date) == [21, 0])
        #expect(hm(try #require(tonight.start.alternative)) == [9, 0])
        // Both still to come: the usual reading.
        #expect(hm(try #require(interpret("sexta às 9")).start.date) == [9, 0])
    }

    @Test("The other reading of a repeating time is its next one")
    func repeatingAlternative() throws {
        let daily = try #require(interpret("todo dia às 7"))
        #expect(hm(daily.start.date) == [19, 0])
        let other = try #require(daily.start.alternative)
        #expect(ymd(other) == [2026, 9, 22])
        #expect(hm(other) == [7, 0])
        #expect(ymd(try #require(interpret("toda segunda às 7")).start.alternative) == [2026, 9, 28])
    }

    @Test(
        "\"meio dia\" without a hyphen is noon next to a day or with minutes",
        arguments: [
            ("amanhã meio dia", [2026, 9, 22], [12, 0]), ("sexta meio dia", [2026, 9, 25], [12, 0]),
            ("meio dia e meia", [2026, 9, 21], [12, 30]), ("meio dia e 15", [2026, 9, 21], [12, 15]),
        ])
    func noonWithoutHyphen(_ example: (text: String, day: [Int], time: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
        #expect(found.text == example.text)
    }

    @Test("Half a day is not noon", arguments: ["meio dia de folga", "trabalhei meio dia"])
    func halfADay(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("Hours written with \"hrs\" before the minutes", arguments: ["15hrs30", "às 15hrs30"])
    func hrsBeforeMinutes(_ text: String) throws {
        #expect(hm(try #require(interpret(text)).start.date) == [15, 30])
    }

    @Test(
        "Diminutives from now",
        arguments: [("daqui 5 minutinhos", [10, 5]), ("daqui a uma horinha", [11, 0])])
    func diminutivesFromNow(_ example: (text: String, time: [Int])) throws {
        #expect(hm(try #require(interpret(example.text)).start.date) == example.time)
    }

    @Test(
        "Hours of something are how long",
        arguments: ["1 hora de academia", "2 horas de estudo", "jejum de 12 horas"])
    func hoursOfSomething(_ text: String) {
        #expect(interpret(text) == nil)
    }
}
