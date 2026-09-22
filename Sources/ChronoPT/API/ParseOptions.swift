import Foundation

/// How `parse` and `interpret` read the text.
public struct ParseOptions: Sendable, Equatable {
    /// Read past dates: "ontem", "anteontem", "sexta passada", "na última
    /// sexta", "semana passada", "mês passado", "há 2 dias", "2 horas atrás".
    /// Off by default, since a reminder in the past is useless. A date that
    /// only names a day, such as "dia 15" or "sexta", still means the next one.
    public var allowsPast: Bool

    /// The hour of `date` when the text gives only the day, from 0 to 23.
    /// Noon by default, away from the midnight shifts of daylight saving time.
    public var defaultHour: Int {
        get { hour }
        set { hour = Self.clamped(newValue) }
    }

    private var hour: Int

    public init(allowsPast: Bool = false, defaultHour: Int = 12) {
        self.allowsPast = allowsPast
        self.hour = Self.clamped(defaultHour)
    }

    private static func clamped(_ hour: Int) -> Int {
        min(max(hour, 0), 23)
    }
}
