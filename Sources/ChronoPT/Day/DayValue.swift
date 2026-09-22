import Foundation

extension DayRules {
    enum Value: Sendable, Equatable {
        case days(Int)
        case weeks(Int)
        case months(Int)
        case years(Int)
        /// Weekday as `Calendar` numbers it: 1 is Sunday, 7 is Saturday.
        case weekday(Int, nextWeek: Bool)
        case date(day: Int, month: Int, year: Int?)
        case dayOfMonth(Int)
        case thisWeek
        case nextWeek
        /// Weeks from the coming weekend: 0 is this one, 1 is "fim de semana
        /// que vem", -1 is "fim de semana passado".
        case weekend(weeks: Int)
        case thisMonth
        case nextMonth
        case startOfNextMonth
        /// Months from this one: 0 is "fim do mês", 1 is "fim do mês que vem".
        case endOfMonth(months: Int)
        case nextYear
        /// The next 1 January, 30 June or 31 December.
        case startOfYear
        case middleOfYear
        case endOfYear
        /// Monday and Tuesday, Wednesday, or Thursday and Friday of the week
        /// that has not gone by yet.
        case startOfWeek
        case middleOfWeek
        case endOfWeek
        /// A whole month: "em outubro", "março de 2027".
        case month(Int, year: Int?)
        /// Days the banks are open: "em 5 dias úteis", "no próximo dia útil",
        /// "primeiro dia útil do mês", "último dia útil do mês".
        case businessDays(Int)
        case firstBusinessDayOfMonth
        case lastBusinessDayOfMonth
        case holiday(Holiday)
        /// The last time that weekday came, before today: "sexta passada".
        case lastWeekday(Int)
        case lastWeek
        case lastMonth
        case lastYear
        case daily
        /// Every so many days, weeks or months: "a cada 15 dias".
        case interval(DateComponents)
        /// Weekdays as `Calendar` numbers them, in the order of the text.
        case weekly([Int])
        case monthly(Int)
        /// From one day to another: "de segunda a sexta", "do dia 10 ao dia 15".
        indirect case range(Value, Value)
        /// A day counted from another: "dois dias antes do natal".
        indirect case shifted(Value, by: DateComponents)

        /// A day of the month, with or without the month: "dia 25", "25/09",
        /// "1º de outubro".
        var isDate: Bool {
            switch self {
            case .date, .dayOfMonth: true
            default: false
            }
        }

        /// "ontem", "sexta passada", "há 2 dias": counts only with
        /// `ChronoPT.Options.allowsPast`.
        var isPast: Bool {
            switch self {
            case .days(let count), .weeks(let count), .months(let count), .years(let count),
                .weekend(let count):
                count < 0
            case .lastWeekday, .lastWeek, .lastMonth, .lastYear: true
            case .range(let from, let to): from.isPast || to.isPast
            case .shifted(let base, _): base.isPast
            default: false
            }
        }

        var recurrence: ChronoPT.Recurrence? {
            switch self {
            case .daily: .daily
            case .interval(let components): .every(components)
            case .weekly(let weekdays): .weekly(on: Set(weekdays.map { DayRules.localeWeekdays[$0 - 1] }))
            case .monthly(let day): .monthly(day: day)
            default: nil
            }
        }

        /// What the text fixes at the start; see `ChronoPT.PartialDate.knownComponents`.
        /// A count from the reference ("amanhã", "semana que vem") fixes the
        /// whole day; a month or a year period fixes only its month or year.
        var knownComponents: Set<Calendar.Component> {
            switch self {
            case .days, .weeks, .months, .years, .thisWeek, .nextWeek, .weekend, .lastWeek, .endOfMonth:
                [.day, .month, .year]
            case .weekday, .lastWeekday:
                [.day, .month, .year, .weekday]
            case .date(_, _, let year):
                year == nil ? [.day, .month] : [.day, .month, .year]
            case .dayOfMonth, .monthly:
                [.day]
            case .thisMonth, .nextMonth, .startOfNextMonth, .lastMonth:
                [.month, .year]
            case .nextYear, .lastYear:
                [.year]
            case .startOfYear, .middleOfYear, .endOfYear, .startOfWeek, .middleOfWeek, .endOfWeek,
                .businessDays, .firstBusinessDayOfMonth, .lastBusinessDayOfMonth:
                [.day, .month, .year]
            case .month(_, let year):
                year == nil ? [.month] : [.month, .year]
            case .holiday:
                [.day, .month]
            case .daily, .interval:
                []
            case .weekly:
                [.weekday]
            case .range(let from, _):
                from.knownComponents
            case .shifted(let base, _):
                base.knownComponents
            }
        }

        /// What the text fixes at the end: the second day of a range, or the
        /// same as the start for a period.
        var endKnownComponents: Set<Calendar.Component> {
            switch self {
            case .range(_, let to): to.knownComponents
            case .shifted(let base, _): base.endKnownComponents
            default: knownComponents
            }
        }
    }

    /// A holiday: on a fixed date, counted from Easter, or on the second Sunday
    /// of a month.
    enum Holiday: Sendable, Equatable {
        case fixed(month: Int, day: Int)
        /// Days from Easter Sunday; `lastDay` when the holiday lasts several days.
        case easter(offset: Int, lastDay: Int? = nil)
        case secondSunday(month: Int)
    }
}
