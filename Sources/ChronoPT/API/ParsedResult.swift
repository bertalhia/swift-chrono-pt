import Foundation

/// A date expression found in the text.
public struct ParsedResult: Sendable, Equatable {
    /// Where the expression is in the input text.
    public let range: Range<String.Index>
    /// The expression as written in the text.
    public let text: String
    /// When it starts.
    public let start: ParsedDate
    /// When it ends, for a period or a range: "semana que vem", "de segunda a
    /// sexta", "das 14h às 16h".
    public let end: ParsedDate?
    /// How the date repeats, for "toda terça", "todo dia às 8" or "todo dia
    /// 5"; `nil` for a single date. `start` is the next time it happens.
    public let recurrence: Recurrence?
}

/// A point in time found in the text, and which of its parts the text gave.
public struct ParsedDate: Sendable, Equatable {
    /// The date. With no time in the text, it is noon of that day, or
    /// `ParseOptions.defaultHour`.
    public let date: Date

    /// The calendar components the text fixes, by naming them ("25/09" names
    /// the day and the month) or by counting from the reference date
    /// ("amanhã" fixes the day, the month and the year).
    ///
    /// The other components come from the reference date or from defaults:
    /// the year of "25/09", the hour of a day with no time, the day of a time
    /// with no day. A part of the day such as "de manhã" gives `.hour` but not
    /// `.minute`, and a weekday adds `.weekday`.
    public let knownComponents: Set<Calendar.Component>

    /// Whether the text gave a time: "às 9", "de manhã", "daqui 2 horas".
    public var hasTime: Bool {
        knownComponents.contains(.hour)
    }
}
