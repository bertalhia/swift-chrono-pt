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
        case period(hour: Int, needsDay: Bool)
        case fromNow(minutes: Int)

        var isClock: Bool { if case .clock = self { true } else { false } }
        var isPeriod: Bool { if case .period = self { true } else { false } }
    }

    /// The time, already decided.
    enum Resolved: Sendable {
        case at(Clock)
        /// A time range: "das 14h às 16h".
        case between(Clock, until: Clock)
        case fromNow(minutes: Int)
    }

    struct Clock: Sendable {
        let hour: Int
        let minute: Int
        /// Midnight of a day is the start of the next day.
        let nextDay: Bool

        func on(_ day: Date, calendar: Calendar) -> Date? {
            guard let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else {
                return nil
            }
            return nextDay ? calendar.date(byAdding: .day, value: 1, to: time) : time
        }
    }

    /// Every time piece, without overlap, in text order.
    static func candidates(in source: TextSource) -> [Piece<Value>] {
        let found =
            clocks(in: source) + minutesToHour(in: source) + noonAndMidnight(in: source)
            + rangeStarts(in: source) + fromNow(in: source) + periods(in: source)
        return Piece.nonOverlapping(found, in: source)
    }

}
