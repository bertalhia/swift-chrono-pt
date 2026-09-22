import Foundation

extension DayRules {
    enum Value: Sendable, Equatable {
        case days(Int)
        case weeks(Int)
        case months(Int)
        case years(Int)
        /// Weekday as `Calendar` numbers it: 1 is Sunday, 7 is Saturday. `week`
        /// is `nil` for the next time it comes, 0 for this week's ("sexta
        /// dessa semana"), 1 for next week's ("sexta que vem").
        case weekday(Int, week: Int?)
        case date(day: Int, month: Int, year: Int?)
        case dayOfMonth(Int)
        /// A weekday and a bare day number: "sexta, 25". The next day with
        /// that number, when it falls on that weekday; otherwise no date.
        case weekdayAndDay(Int, day: Int)
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
        /// A part of the year: "primeiro semestre" is part 1 of 2, "terceiro
        /// trimestre" part 3 of 4. Without a year, the next one that has not
        /// ended.
        case yearPart(Int, of: Int, year: Int?)
        /// The part of the year under way, or one after it: "este semestre"
        /// is 0, "próximo trimestre" is 1.
        case yearPartFromNow(Int, of: Int)
        /// Half a month, a "quinzena": 1 is days 1 to 15, 2 the rest. Without
        /// a month, this month's if it has not ended.
        case halfMonth(Int, month: Int?, year: Int?)
        /// Days the banks are open: "em 5 dias úteis", "no próximo dia útil",
        /// "primeiro dia útil do mês", "último dia útil do mês".
        case businessDays(Int)
        /// The business day in that place in the month: 1 is "primeiro dia
        /// útil", 5 "5º dia útil", -1 "último dia útil". This month's, or the
        /// next one's once it has gone by.
        case nthBusinessDayOfMonth(Int)
        /// A weekday in its place in the month, once: "a primeira segunda do
        /// mês", "na última sexta do mês".
        case nthWeekdayOfMonth(Int, weekday: Int)
        /// A week of the month, from its first day: 1 is days 1 to 7, -1 the
        /// last seven days. "na primeira semana de outubro".
        case weekOfMonth(Int)
        /// A day inside a period: "semana que vem, na quarta", "dia 25 do mês
        /// que vem", "fim de outubro", "dia 20 de outubro do ano que vem".
        indirect case within(Value, Value)
        /// A holiday, in the year the text gave: "no natal de 2027".
        case holiday(Holiday, year: Int?)
        /// The last time that weekday came, before today: "sexta passada".
        case lastWeekday(Int)
        /// Weeks, months or years back: 1 is "semana passada", 2 "semana
        /// retrasada".
        case lastWeek(Int)
        case lastMonth(Int)
        case lastYear(Int)
        case daily
        /// Every so many days, weeks or months: "a cada 15 dias".
        case interval(DateComponents)
        /// Weekdays as `Calendar` numbers them, in the order of the text.
        case weekly([Int])
        case monthly(Int)
        /// So many times in each day, week, month or year: "3x ao dia".
        case timesPer(Int, DateComponents)
        /// A weekday in its place in the month, each month: "toda última
        /// sexta do mês" is -1 and Friday.
        case nthWeekday(Int, weekday: Int)
        /// Every year, in a month or from today: "todo ano em julho".
        case yearly(month: Int?)
        /// Every year on a date: "todo 25 de dezembro".
        case yearlyOn(day: Int, month: Int)
        /// A repeating day and where it stops: "toda terça até dezembro".
        indirect case repeating(Value, until: Limit)
        /// A repeating day and how many times in each unit: "toda terça, 3
        /// vezes ao dia".
        indirect case rated(Value, Int, per: DateComponents)
        /// From one day to another: "de segunda a sexta", "do dia 10 ao dia 15".
        indirect case range(Value, Value)
        /// A day counted from another: "dois dias antes do natal".
        indirect case shifted(Value, by: DateComponents)
        /// From a day, for so long: "amanhã por 3 dias" is tomorrow and the
        /// two days after it. Alone it counts from today: "por 3 dias".
        indirect case lasting(Value, for: DateComponents)
        /// Monday to Friday, from today: "durante a semana". On a weekend,
        /// next week's.
        case workWeek
        /// A date and time written in full, ISO style: "2026-10-15T14:30".
        /// The offset, in seconds east of UTC, is the one the text gave.
        case dateTime(DateComponents, offset: Int?)

        /// A day of the month, with or without the month: "dia 25", "25/09",
        /// "1º de outubro".
        var isDate: Bool {
            switch self {
            case .date, .dayOfMonth: true
            default: false
            }
        }

        /// A day that comes back on the calendar, so its next time is the one
        /// meant: "dia 22", "25/12", "sexta", "natal", "em outubro".
        var comesBack: Bool {
            switch self {
            case .date(_, _, nil), .dayOfMonth, .holiday(_, nil), .weekday(_, nil), .month(_, nil): true
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
            case .shifted(let base, _), .lasting(let base, _): base.isPast
            case .within(let inner, let outer): inner.isPast || outer.isPast
            default: false
            }
        }

        var recurrence: ChronoPT.Recurrence? {
            switch self {
            case .daily: .daily()
            case .interval(let components): ChronoPT.Recurrence(every: components)
            case .weekly(let weekdays): .weekly(on: Set(weekdays.map { DayRules.localeWeekdays[$0 - 1] }))
            case .monthly(let day): .monthly(day: day)
            case .timesPer(let count, let unit):
                // Once a week is every week.
                ChronoPT.Recurrence(every: unit).map { rule in
                    var rule = rule
                    rule.rate = count > 1 ? ChronoPT.Recurrence.Rate(count: count, per: rule.frequency) : nil
                    return rule
                }
            case .nthWeekday(let ordinal, let weekday):
                ChronoPT.Recurrence(
                    frequency: .monthly, weekdays: [.nth(ordinal, DayRules.localeWeekdays[weekday - 1])])
            case .yearly(let month):
                ChronoPT.Recurrence(frequency: .yearly, months: month.map { [$0] } ?? [])
            case .yearlyOn(let day, let month):
                ChronoPT.Recurrence(frequency: .yearly, daysOfMonth: [day], months: [month])
            case .repeating(let base, _): base.recurrence
            case .rated(let base, let count, let unit):
                base.recurrence.map { rule in
                    var rule = rule
                    rule.rate = ChronoPT.Recurrence.unit(of: unit).map {
                        ChronoPT.Recurrence.Rate(count: count, per: $0.1)
                    }
                    return rule
                }
            default: nil
            }
        }

        /// What the text fixes at the start; see `ChronoPT.PartialDate.knownComponents`.
        /// A count from the reference ("amanhã", "semana que vem") fixes the
        /// whole day; a month or a year period fixes only its month or year.
        var knownComponents: Set<Calendar.Component> {
            switch self {
            case .days, .weeks, .months, .years, .thisWeek, .nextWeek, .weekend, .lastWeek, .endOfMonth,
                .workWeek:
                [.day, .month, .year]
            case .weekday, .lastWeekday, .nthWeekdayOfMonth:
                [.day, .month, .year, .weekday]
            case .within(let inner, _):
                inner.knownComponents.contains(.weekday)
                    ? [.day, .month, .year, .weekday] : [.day, .month, .year]
            case .weekdayAndDay:
                [.day, .weekday]
            case .date(_, _, let year):
                year == nil ? [.day, .month] : [.day, .month, .year]
            case .dayOfMonth, .monthly:
                [.day]
            case .thisMonth, .nextMonth, .startOfNextMonth, .lastMonth:
                [.month, .year]
            case .nextYear, .lastYear:
                [.year]
            case .startOfYear, .middleOfYear, .endOfYear, .startOfWeek, .middleOfWeek, .endOfWeek,
                .businessDays, .nthBusinessDayOfMonth, .weekOfMonth:
                [.day, .month, .year]
            case .month(_, let year), .yearPart(_, _, let year):
                year == nil ? [.month] : [.month, .year]
            case .yearPartFromNow:
                [.month, .year]
            case .halfMonth(_, let month, let year):
                month == nil ? [.day] : year == nil ? [.day, .month] : [.day, .month, .year]
            case .holiday:
                [.day, .month]
            case .daily, .interval, .timesPer:
                []
            case .weekly, .nthWeekday:
                [.weekday]
            case .yearly(let month):
                month == nil ? [] : [.month]
            case .yearlyOn:
                [.day, .month]
            case .repeating(let base, _), .rated(let base, _, _):
                base.knownComponents
            case .range(let from, _):
                from.knownComponents
            case .shifted(let base, _), .lasting(let base, _):
                base.knownComponents
            case .dateTime(_, let offset):
                offset == nil
                    ? [.day, .month, .year, .hour, .minute]
                    : [.day, .month, .year, .hour, .minute, .timeZone]
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

    /// Where a repeating day stops.
    enum Limit: Sendable, Equatable {
        /// On this day, the last one of a period: "até dezembro".
        case day(Value)
        /// So long after it starts: "por 10 dias".
        case length(DateComponents)
        /// After so many times: "5 vezes".
        case count(Int)
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
