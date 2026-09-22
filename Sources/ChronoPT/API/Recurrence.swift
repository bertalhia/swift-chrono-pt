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
