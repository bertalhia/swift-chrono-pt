import Foundation
import Testing

@testable import ChronoPT

/// The rules count Gregorian months, weekdays and years. A caller may pass any
/// calendar, and the time zone is the part that has to be honoured.
@Suite("Calendars and time zones")
struct CalendarTests {
    static func calendar(_ identifier: Calendar.Identifier, _ zone: String = "America/Sao_Paulo") -> Calendar
    {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    @Test(
        "Another calendar gives the same instant",
        arguments: [
            Calendar.Identifier.buddhist, .japanese, .hebrew, .islamicUmmAlQura, .persian, .iso8601,
        ])
    func otherCalendars(_ identifier: Calendar.Identifier) throws {
        let found = try #require(
            ChronoPT.interpret("25/09/2026 às 14h", reference: monday, calendar: Self.calendar(identifier)))
        #expect(ymd(found.start.date) == [2026, 9, 25])
        #expect(hm(found.start.date) == [14, 0])
    }

    @Test(
        "Easter still lands on Easter",
        arguments: [Calendar.Identifier.buddhist, .japanese, .hebrew, .iso8601])
    func easter(_ identifier: Calendar.Identifier) throws {
        let start = reference(2026, 1, 5)
        let found = try #require(
            ChronoPT.interpret("na páscoa", reference: start, calendar: Self.calendar(identifier)))
        #expect(ymd(found.start.date) == [2026, 4, 5])
    }

    @Test("A time inside a daylight saving gap stays on its day")
    func daylightSavingGap() throws {
        // Lord Howe Island moves the clock from 02:00 to 02:30 on 4 October 2026.
        let lordHowe = Self.calendar(.gregorian, "Australia/Lord_Howe")
        let start = lordHowe.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 10))!
        let found = try #require(ChronoPT.interpret("amanhã às 2h", reference: start, calendar: lordHowe))
        let parts = lordHowe.dateComponents([.year, .month, .day, .hour, .minute], from: found.start.date)
        #expect([parts.year, parts.month, parts.day] == [2026, 10, 4])
        #expect([parts.hour, parts.minute] == [2, 30])
    }
}
