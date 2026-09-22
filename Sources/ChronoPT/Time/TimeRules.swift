import Foundation

/// Time rules: clock times ("às 9", "14h", "10:30", "às sete da noite",
/// "meio-dia e meia"), parts of the day and moments ("de manhã", "no almoço",
/// "depois da janta", "antes de dormir"), and time from now ("daqui 2 horas").
///
/// A meal is a time only with a preposition of time: "no almoço" (at lunch)
/// is 12:00, while "para o almoço" (for lunch) says what a purchase is for and
/// sets no time.
enum TimeRules {
    enum Value: Sendable {
        /// `ambiguous` when the words don't say morning or evening: "às 7".
        /// `minute` is negative for minutes before the hour: "quinze para as
        /// oito" is 8:00 and -15. `needsEnd` for a bare hour that counts only
        /// as the start of a range: "de 9 a 11h".
        case clock(hour: Int, minute: Int, ambiguous: Bool, nextDay: Bool, needsEnd: Bool = false)
        /// Part of the day or moment. `needsDay` when it is not a time on its
        /// own: "chegar cedo".
        case period(hour: Int, minute: Int, needsDay: Bool)
        /// A whole part of the day, in hours: "a manhã toda" is 6 to 12.
        case span(from: Int, until: Int)
        /// The whole day, which has no hours: "o dia todo". Not a time on
        /// its own.
        case allDay
        case fromNow(minutes: Int)
        /// The time zone the clock time is read in: "15h BRT", "às 9
        /// horário de Brasília".
        case zone(TimeZone)

        var isClock: Bool { if case .clock = self { true } else { false } }
        var isPeriod: Bool { if case .period = self { true } else { false } }
    }

    /// The time, already decided.
    enum Resolved: Sendable {
        case at(Clock)
        /// A time range: "das 14h às 16h".
        case between(Clock, until: Clock)
        case allDay
        case fromNow(minutes: Int)
    }

    struct Clock: Sendable {
        let hour: Int
        let minute: Int
        /// Days past the one it is read on: midnight is the start of the next,
        /// and the end of a range can be further still.
        let dayOffset: Int

        init(hour: Int, minute: Int, dayOffset: Int = 0) {
            self.hour = hour
            self.minute = minute
            self.dayOffset = dayOffset
        }

        /// The clock time on the calendar day of `day`, read in `zone` when
        /// the text named one: "15h BRT" is 15:00 in Brasília on that day.
        func on(_ day: Date, calendar: Calendar, in zone: TimeZone?) -> Date? {
            guard let zone, zone != calendar.timeZone else { return on(day, calendar: calendar) }
            var zoned = calendar
            zoned.timeZone = zone
            guard let start = zoned.date(from: calendar.dateComponents([.year, .month, .day], from: day))
            else {
                return nil
            }
            return on(start, calendar: zoned)
        }

        func on(_ day: Date, calendar: Calendar) -> Date? {
            var time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            // A wall time inside a daylight saving gap does not exist, and
            // Foundation answers with the next day. Count from the start of the
            // day instead, which lands on the first time there is.
            if let found = time, !calendar.isDate(found, inSameDayAs: day) {
                time = calendar.date(
                    byAdding: DateComponents(hour: hour, minute: minute),
                    to: calendar.startOfDay(for: day)
                )
            }
            guard let time else { return nil }
            return dayOffset == 0 ? time : calendar.date(byAdding: .day, value: dayOffset, to: time)
        }
    }

    /// Every time piece, without overlap, in text order.
    /// `days` are where the day rules found something; `claimed` the ones
    /// that count on their own. A number a day claims is not a time: "dia
    /// 10 às 14h", "de 10 a 15 de outubro".
    static func candidates(
        in source: TextSource, moments: [String: ChronoPT.TimeOfDay] = [:], days: [Range<String.Index>] = [],
        claimed: [Range<String.Index>] = []
    ) -> [Piece<Value>] {
        let found =
            clocks(in: source) + englishClocks(in: source) + minutesToHour(in: source)
            + noonAndMidnight(in: source)
            + rangeStarts(in: source, days: days) + fromNow(in: source) + periods(in: source)
            + periods(in: source, index: index(of: moments), priority: 1) + zones(in: source)
        return Piece.nonOverlapping(
            found.filter { piece in !claimed.contains { $0.overlaps(piece.range) } }, in: source)
    }

}
