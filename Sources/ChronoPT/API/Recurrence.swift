import Foundation

/// How a date repeats.
public enum Recurrence: Sendable, Equatable {
    /// Every day: "todo dia", "todos os dias", "diariamente".
    case daily
    /// On these weekdays every week: "toda terça", "às segundas e quartas".
    case weekly(on: Set<Locale.Weekday>)
    /// On this day of every month: "todo dia 5", "todo mês no dia 10".
    case monthly(day: Int)
    /// Every so many days, weeks or months: "a cada 15 dias", "de 2 em 2
    /// semanas", "toda semana", "todo mês". The components are ready for
    /// `Calendar.date(byAdding:to:)`.
    case every(DateComponents)
}
