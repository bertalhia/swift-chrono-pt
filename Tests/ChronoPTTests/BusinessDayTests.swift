import Testing

@testable import ChronoPT

@Suite("Business days")
struct BusinessDayTests {
    @Test(
        "Counting business days skips weekends",
        arguments: [
            ("em 5 dias úteis", [2026, 9, 28]),
            ("prazo de 5 dias úteis", [2026, 9, 28]),
            ("em até 2 dias úteis", [2026, 9, 23]),
            ("compensa em 1 dia útil", [2026, 9, 22]),
            ("no próximo dia útil", [2026, 9, 22]),
            ("primeiro dia útil do mês", [2026, 10, 1]),
            ("último dia útil do mês", [2026, 9, 30]),
        ])
    func counting(_ example: (text: String, day: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(found.start.hasTime == false)
    }

    @Test("Counting business days skips holidays")
    func holidays() throws {
        // Christmas falls on a Friday in 2026.
        let christmasWeek = try #require(interpret("em 2 dias úteis", reference: reference(2026, 12, 23)))
        #expect(ymd(christmasWeek.start.date) == [2026, 12, 28])

        // Good Friday 2027 is 26 March.
        let easter = try #require(interpret("em 1 dia útil", reference: reference(2027, 3, 25)))
        #expect(ymd(easter.start.date) == [2027, 3, 29])

        // Carnival Tuesday 2027 is 9 February.
        let carnival = try #require(interpret("no próximo dia útil", reference: reference(2027, 2, 8)))
        #expect(ymd(carnival.start.date) == [2027, 2, 10])
    }

    @Test("A business day with a time")
    func withTime() throws {
        let found = try #require(interpret("pagar em 2 dias úteis às 14h"))
        #expect(ymd(found.start.date) == [2026, 9, 23])
        #expect(hm(found.start.date) == [14, 0])
    }
}
