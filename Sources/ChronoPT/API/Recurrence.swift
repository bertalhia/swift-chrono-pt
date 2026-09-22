import Foundation

extension ChronoPT {
    /// How a date repeats.
    public enum Recurrence: Sendable, Hashable, Codable {
        /// Every day: "todo dia", "todos os dias", "diariamente".
        case daily
        /// On these weekdays every week: "toda terça", "às segundas e quartas".
        case weekly(on: Set<Locale.Weekday>)
        /// On this day of every month: "todo dia 5", "todo mês no dia 10".
        case monthly(day: Int)
        /// Every so many minutes, hours, days, weeks or months: "a cada 15
        /// dias", "de 8 em 8 horas", "toda semana". The components are ready
        /// for `Calendar.date(byAdding:to:)`.
        case every(DateComponents)
    }
}

extension ChronoPT.Recurrence: CustomStringConvertible {
    /// A stable description, weekdays in week order, for logs and bug reports.
    public var description: String {
        switch self {
        case .daily:
            return "daily"
        case .weekly(let weekdays):
            let order: [Locale.Weekday] = [
                .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
            ]
            return "weekly on " + order.filter(weekdays.contains).map(\.rawValue).joined(separator: ", ")
        case .monthly(let day):
            return "monthly on day \(day)"
        case .every(let components):
            let parts: [(Int?, String)] = [
                (components.year, "years"), (components.month, "months"), (components.weekOfYear, "weeks"),
                (components.day, "days"), (components.hour, "hours"), (components.minute, "minutes"),
            ]
            return "every "
                + parts.compactMap { count, unit in count.map { "\($0) \(unit)" } }.joined(separator: ", ")
        }
    }
}
