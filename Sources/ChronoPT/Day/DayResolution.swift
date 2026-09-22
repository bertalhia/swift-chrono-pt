import Foundation

/// From a day the rules found to the date it means.
extension DayRules {
    /// The start of the mentioned day and, for a period, the start of its last day.
    static func resolve(_ value: Value, reference: Date, calendar: Calendar) -> (start: Date, end: Date?)? {
        let today = calendar.startOfDay(for: reference)

        switch value {
        case .days(let count):
            return calendar.date(byAdding: .day, value: count, to: today).map { ($0, nil) }

        case .weeks(let count):
            return calendar.date(byAdding: .day, value: 7 * count, to: today).map { ($0, nil) }

        case .years(let count):
            return calendar.date(byAdding: .year, value: count, to: today).map { ($0, nil) }

        case .months(let count):
            return calendar.date(byAdding: .month, value: count, to: today).map { ($0, nil) }

        case .weekday(let weekday, let week?):
            // Weeks run Monday to Sunday. This week's day that has gone by is
            // no date: "quinta dessa semana" said on a Friday.
            let offset = (calendar.component(.weekday, from: today) + 5) % 7
            guard
                let day = calendar.date(
                    byAdding: .day, value: 7 * week + (weekday + 5) % 7 - offset, to: today),
                day >= today
            else { return nil }
            return (day, nil)

        case .weekday(let weekday, nil):
            // The next time that weekday comes, not counting today: "sexta"
            // said on a Friday is next week's.
            return calendar.nextDate(
                after: today, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime
            )
            .map { ($0, nil) }

        case .date(let day, let month, let year):
            guard (1...12).contains(month), (1...daysInMonth[month - 1]).contains(day) else { return nil }
            if let year {
                let components = DateComponents(year: year, month: month, day: day)
                // The calendar rolls a date that doesn't exist over (29/02 in a
                // common year becomes 01/03); then it is not a date.
                guard let date = calendar.date(from: components),
                    calendar.component(.day, from: date) == day
                else { return nil }
                return (date, nil)
            }
            // Without a year, the next time that date comes, counting today.
            return calendar.nextDate(
                after: today.addingTimeInterval(-1),
                matching: DateComponents(month: month, day: day),
                matchingPolicy: .strict
            ).map { ($0, nil) }

        case .dayOfMonth(let day):
            guard (1...31).contains(day) else { return nil }
            return calendar.nextDate(
                after: today.addingTimeInterval(-1),
                matching: DateComponents(day: day),
                matchingPolicy: .strict
            ).map { ($0, nil) }

        case .weekdayAndDay(let weekday, let day):
            guard let date = resolve(.dayOfMonth(day), reference: reference, calendar: calendar)?.start,
                calendar.component(.weekday, from: date) == weekday
            else { return nil }
            return (date, nil)

        case .thisWeek:
            // From today to Sunday; on a Sunday, just today.
            let weekday = calendar.component(.weekday, from: today)
            guard weekday != 1 else { return (today, nil) }
            return calendar.date(byAdding: .day, value: 8 - weekday, to: today).map { (today, $0) }

        case .nextWeek:
            guard let monday = nextMonday(after: today, calendar: calendar),
                let sunday = calendar.date(byAdding: .day, value: 6, to: monday)
            else { return nil }
            return (monday, sunday)

        case .weekend(let weeks):
            let weekday = calendar.component(.weekday, from: today)
            // On Saturday it is this weekend; on Sunday, what is left of it.
            if weeks == 0, weekday == 1 { return (today, nil) }
            // Counting from the Saturday of the weekend under way, which on a
            // Sunday was yesterday.
            let coming =
                weekday == 7
                ? today
                : weekday == 1
                    ? calendar.date(byAdding: .day, value: -1, to: today)
                    : calendar.nextDate(
                        after: today, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime)
            guard let coming,
                let saturday = calendar.date(byAdding: .day, value: 7 * weeks, to: coming),
                let sunday = calendar.date(byAdding: .day, value: 1, to: saturday)
            else { return nil }
            return (saturday, sunday)

        case .thisMonth:
            // From today to the last day; on the last day, just today.
            guard let last = lastDayOfMonth(today, calendar: calendar) else { return nil }
            return (today, last == today ? nil : last)

        case .nextMonth:
            guard let first = firstDayOfNextMonth(today, calendar: calendar),
                let last = lastDayOfMonth(first, calendar: calendar)
            else { return nil }
            return (first, last)

        case .startOfNextMonth:
            return firstDayOfNextMonth(today, calendar: calendar).map { ($0, nil) }

        case .nextYear:
            guard let thisYear = calendar.dateInterval(of: .year, for: today)?.start,
                let first = calendar.date(byAdding: .year, value: 1, to: thisYear),
                let last = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: first)
            else { return nil }
            return (first, last)

        case .endOfMonth(let months):
            guard let month = calendar.date(byAdding: .month, value: months, to: today) else { return nil }
            return lastDayOfMonth(month, calendar: calendar).map { ($0, nil) }

        case .lastWeekday(let weekday, let weeks):
            return calendar.nextDate(
                after: today,
                matching: DateComponents(weekday: weekday),
                matchingPolicy: .nextTime,
                direction: .backward
            ).flatMap { calendar.date(byAdding: .day, value: -7 * (weeks - 1), to: $0) }.map { ($0, nil) }

        case .lastWeek(let weeks):
            // Monday to Sunday of a week before this one.
            let weekday = calendar.component(.weekday, from: today)
            guard let thisMonday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today),
                let monday = calendar.date(byAdding: .day, value: -7 * weeks, to: thisMonday),
                let sunday = calendar.date(byAdding: .day, value: 6, to: monday)
            else { return nil }
            return (monday, sunday)

        case .lastMonth(let months):
            guard let thisMonth = calendar.dateInterval(of: .month, for: today)?.start,
                let first = calendar.date(byAdding: .month, value: -months, to: thisMonth),
                let last = lastDayOfMonth(first, calendar: calendar)
            else { return nil }
            return (first, last)

        case .lastYear(let years):
            guard let thisYear = calendar.dateInterval(of: .year, for: today)?.start,
                let first = calendar.date(byAdding: .year, value: -years, to: thisYear),
                let last = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: first)
            else { return nil }
            return (first, last)

        case .daily, .interval:
            return (today, nil)

        case .weekly(let weekdays, _):
            // The next of these weekdays, counting today.
            return weekdays.compactMap { weekday in
                calendar.nextDate(
                    after: today.addingTimeInterval(-1),
                    matching: DateComponents(weekday: weekday),
                    matchingPolicy: .nextTime
                )
            }.min().map { ($0, nil) }

        case .monthly(let days):
            // The first of the days to come; -1 is the last day of the month.
            return days.compactMap { day in
                resolve(
                    day < 0 ? .endOfMonth(months: 0) : .dayOfMonth(day), reference: reference,
                    calendar: calendar)
            }.min { $0.start < $1.start }

        case .timesPer, .yearly(month: nil):
            return (today, nil)

        case .yearly(let month?):
            return resolve(.month(month, year: nil), reference: reference, calendar: calendar).map {
                ($0.start, nil)
            }

        case .yearlyOn(let day, let month):
            return resolve(.date(day: day, month: month, year: nil), reference: reference, calendar: calendar)

        case .nthWeekday(let ordinal, let weekday):
            // The next one, counting today: the month rolls over once this
            // month's has gone by.
            // A fifth weekday can be months away.
            for months in 0...12 {
                guard let month = calendar.date(byAdding: .month, value: months, to: today),
                    let day = nthWeekday(ordinal, weekday, inMonthOf: month, calendar: calendar)
                else { continue }
                if day >= today { return (day, nil) }
            }
            return nil

        case .repeating(let base, _), .rated(let base, _, _):
            return resolve(base, reference: reference, calendar: calendar)

        case .range(let from, let to):
            // The end is the first time `to` comes from the start on: "de
            // segunda a sexta" said on a Monday runs from next Monday to that
            // Friday.
            guard let first = resolve(from, reference: reference, calendar: calendar),
                var last = resolve(to, reference: reference, calendar: calendar)
            else { return nil }
            if (last.end ?? last.start) < first.start,
                let later = resolve(to, reference: first.start, calendar: calendar)
            {
                last = later
            }
            let end = last.end ?? last.start
            return end > first.start ? (first.start, end) : first

        case .startOfYear, .middleOfYear, .endOfYear:
            // The next 1 January, 30 June or 31 December, counting today.
            let (month, day) =
                switch value {
                case .startOfYear: (1, 1)
                case .middleOfYear: (6, 30)
                default: (12, 31)
                }
            return calendar.nextDate(
                after: today.addingTimeInterval(-1),
                matching: DateComponents(month: month, day: day),
                matchingPolicy: .strict
            ).map { ($0, nil) }

        case .startOfWeek, .middleOfWeek, .endOfWeek:
            // Monday and Tuesday, Wednesday, or Thursday and Friday; the next
            // week once this one's part has gone by.
            let (first, last) =
                switch value {
                case .startOfWeek: (0, 1)
                case .middleOfWeek: (2, 2)
                default: (3, 4)
                }
            let weekday = calendar.component(.weekday, from: today)
            guard let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today),
                var start = calendar.date(byAdding: .day, value: first, to: monday),
                var end = calendar.date(byAdding: .day, value: last, to: monday)
            else { return nil }
            if end < today {
                guard let later = calendar.date(byAdding: .day, value: 7, to: start),
                    let laterEnd = calendar.date(byAdding: .day, value: 7, to: end)
                else { return nil }
                (start, end) = (later, laterEnd)
            }
            // A part under way runs from today.
            start = max(start, today)
            return (start, start == end ? nil : end)

        case .month(let month, let year?):
            guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                let last = lastDayOfMonth(first, calendar: calendar)
            else { return nil }
            return (first, last)

        case .month(let month, nil):
            // The next one that has not ended; the month under way runs from
            // today: "em setembro" said in September.
            let thisYear = calendar.component(.year, from: today)
            for year in thisYear...(thisYear + 1) {
                guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                    let last = lastDayOfMonth(first, calendar: calendar)
                else { return nil }
                if last >= today { return fromToday((first, last), today: today) }
            }
            return nil

        case .yearPart(let part, let parts, let year):
            if let year { return yearPart(part, of: parts, year: year, calendar: calendar) }
            let thisYear = calendar.component(.year, from: today)
            return (thisYear...(thisYear + 1)).lazy
                .compactMap { yearPart(part, of: parts, year: $0, calendar: calendar) }
                .first { $0.end >= today }
                .map { fromToday($0, today: today) }

        case .yearPartFromNow(let offset, let parts):
            guard parts > 0, 12 % parts == 0 else { return nil }
            let index = (calendar.component(.month, from: today) - 1) / (12 / parts) + offset
            let year = calendar.component(.year, from: today) + index / parts
            return yearPart(index % parts + 1, of: parts, year: year, calendar: calendar)
                .map { fromToday($0, today: today) }

        case .halfMonth(let half, let month, let year):
            if let month, let year {
                return calendar.date(from: DateComponents(year: year, month: month, day: 1))
                    .flatMap { halfMonth(half, from: $0, calendar: calendar) }
            }
            // The first months to try: this month's half or the next one's,
            // or the month named in this year or the next.
            let firsts: [Date?] =
                if let month {
                    (0...1).map {
                        calendar.date(
                            from: DateComponents(
                                year: calendar.component(.year, from: today) + $0, month: month, day: 1))
                    }
                } else {
                    (0...1).map { months in
                        calendar.dateInterval(of: .month, for: today)
                            .flatMap { calendar.date(byAdding: .month, value: months, to: $0.start) }
                    }
                }
            return firsts.lazy.compactMap { $0.flatMap { halfMonth(half, from: $0, calendar: calendar) } }
                .first { $0.end >= today }
                .map { fromToday($0, today: today) }

        case .dateTime:
            return instant(of: value, calendar: calendar).map { (calendar.startOfDay(for: $0), nil) }

        case .lasting(let base, let length):
            // The last day is the day before the length has gone by: three
            // days from the 21st end on the 23rd.
            guard let first = resolve(base, reference: reference, calendar: calendar)?.start,
                let after = calendar.date(byAdding: length, to: first),
                let last = calendar.date(byAdding: .day, value: -1, to: after)
            else { return nil }
            return (first, last > first ? last : nil)

        case .workWeek:
            let weekday = calendar.component(.weekday, from: today)
            let start =
                weekday == 1 || weekday == 7
                ? nextMonday(after: today, calendar: calendar) : today
            guard let start,
                let friday = calendar.date(
                    byAdding: .day, value: 6 - calendar.component(.weekday, from: start), to: start)
            else { return nil }
            return (start, friday > start ? friday : nil)

        case .shifted(let base, let shift):
            // One day, counted back from the first day or forward from the
            // last: "dois dias antes do carnaval" is before it begins.
            func shifted(from reference: Date) -> (days: (start: Date, end: Date?), date: Date)? {
                guard let days = resolve(base, reference: reference, calendar: calendar) else { return nil }
                let forward = [shift.day, shift.weekOfYear, shift.month, shift.year].contains {
                    ($0 ?? 0) > 0
                }
                return calendar.date(byAdding: shift, to: forward ? days.end ?? days.start : days.start)
                    .map { (days, $0) }
            }
            guard let first = shifted(from: reference) else { return nil }
            // A date that comes back every year counts from its next time
            // when this one's shifted day has gone by: "véspera do natal"
            // said on Christmas Day is next year's.
            guard first.date < today, base.comesBack,
                let next = calendar.date(byAdding: .day, value: 1, to: first.days.end ?? first.days.start),
                let later = shifted(from: next)
            else { return (first.date, nil) }
            return (later.date, nil)

        case .businessDays(let count):
            // Counting from today, skipping weekends and the days the banks close.
            var date = today
            var left = count
            var bank = BankDays(calendar: calendar)
            while left > 0 {
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
                date = next
                if bank.isOpen(date) { left -= 1 }
            }
            return (date, nil)

        case .nthBusinessDayOfMonth, .nthWeekdayOfMonth, .weekOfMonth:
            // This month's, or the next month's once it has gone by; a week
            // under way runs from today.
            for months in 0...12 {
                guard let day = calendar.date(byAdding: .month, value: months, to: today),
                    let first = calendar.dateInterval(of: .month, for: day)?.start,
                    let last = lastDayOfMonth(first, calendar: calendar),
                    let found = inside(value, span: (first, last), calendar: calendar)
                else { continue }
                if (found.end ?? found.start) >= today {
                    return found.end.map { fromToday((found.start, $0), today: today) } ?? found
                }
            }
            return nil

        case .within(let inner, let outer):
            guard let span = resolve(outer, reference: reference, calendar: calendar) else { return nil }
            return inside(inner, span: span, calendar: calendar)

        case .holiday(let holiday, let year?):
            return days(of: holiday, in: year, calendar: calendar)

        case .holiday(let holiday, nil):
            // The next time the holiday comes, counting today; one that lasts
            // several days and has started counts from today.
            let year = calendar.component(.year, from: today)
            for year in year...(year + 1) {
                guard let days = days(of: holiday, in: year, calendar: calendar) else { return nil }
                guard (days.end ?? days.start) >= today else { continue }
                let start = max(days.start, today)
                return (start, days.end == start ? nil : days.end)
            }
            return nil
        }
    }

    static func days(of holiday: Holiday, in year: Int, calendar: Calendar) -> (start: Date, end: Date?)? {
        switch holiday {
        case .fixed(let month, let day):
            return calendar.date(from: DateComponents(year: year, month: month, day: day)).map { ($0, nil) }
        case .easter(let offset, let lastDay):
            guard let easter = easter(in: year, calendar: calendar),
                let start = calendar.date(byAdding: .day, value: offset, to: easter)
            else { return nil }
            return (start, lastDay.flatMap { calendar.date(byAdding: .day, value: $0, to: easter) })
        case .secondSunday(let month):
            return calendar.date(from: DateComponents(year: year, month: month, day: 1))
                .flatMap { nthWeekday(2, 1, inMonthOf: $0, calendar: calendar) }
                .map { ($0, nil) }
        }
    }

    /// The weekday in its place in the month of `day`: 2 and Sunday is the
    /// second Sunday, -1 and Friday the last Friday. `nil` for a fifth one the
    /// month does not have.
    static func nthWeekday(_ ordinal: Int, _ weekday: Int, inMonthOf day: Date, calendar: Calendar) -> Date? {
        guard ordinal != 0, let first = calendar.dateInterval(of: .month, for: day)?.start,
            let last = lastDayOfMonth(first, calendar: calendar)
        else { return nil }
        let date: Date?
        if ordinal > 0 {
            let forward = (weekday - calendar.component(.weekday, from: first) + 7) % 7
            date = calendar.date(byAdding: .day, value: forward + 7 * (ordinal - 1), to: first)
        } else {
            let back = (calendar.component(.weekday, from: last) - weekday + 7) % 7
            date = calendar.date(byAdding: .day, value: -back + 7 * (ordinal + 1), to: last)
        }
        guard let date, calendar.isDate(date, equalTo: first, toGranularity: .month) else { return nil }
        return date
    }

    /// Easter Sunday by the Gregorian computus (Meeus/Jones/Butcher).
    static func easter(in year: Int, calendar: Calendar) -> Date? {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// The first and last day of part `part` of `parts` in the year.
    static func yearPart(_ part: Int, of parts: Int, year: Int, calendar: Calendar) -> (
        start: Date, end: Date
    )? {
        guard parts > 0, 12 % parts == 0, (1...parts).contains(part),
            let first = calendar.date(
                from: DateComponents(year: year, month: (part - 1) * 12 / parts + 1, day: 1)),
            let last = calendar.date(byAdding: DateComponents(month: 12 / parts, day: -1), to: first)
        else { return nil }
        return (first, last)
    }

    /// The first and last day of a half of the month that starts on `first`.
    static func halfMonth(_ half: Int, from first: Date, calendar: Calendar) -> (start: Date, end: Date)? {
        guard let fifteenth = calendar.date(byAdding: .day, value: 14, to: first) else { return nil }
        switch half {
        case 1: return (first, fifteenth)
        case 2:
            guard let sixteenth = calendar.date(byAdding: .day, value: 1, to: fifteenth),
                let last = lastDayOfMonth(first, calendar: calendar)
            else { return nil }
            return (sixteenth, last)
        default: return nil
        }
    }

    /// A period that has started runs from today: "no segundo semestre" said
    /// in September.
    static func fromToday(_ days: (start: Date, end: Date), today: Date) -> (start: Date, end: Date?) {
        let start = max(days.start, today)
        return (start, days.end == start ? nil : days.end)
    }

    static func firstDayOfNextMonth(_ day: Date, calendar: Calendar) -> Date? {
        guard let thisMonth = calendar.dateInterval(of: .month, for: day)?.start else { return nil }
        return calendar.date(byAdding: .month, value: 1, to: thisMonth)
    }

    /// The moment a full date and time names, in the offset the text gave or,
    /// without one, in the calendar's time zone.
    static func instant(of value: Value, calendar: Calendar) -> Date? {
        guard case let .dateTime(components, offset) = value else { return nil }
        var calendar = calendar
        if let offset, let zone = TimeZone(secondsFromGMT: offset) { calendar.timeZone = zone }
        return calendar.date(from: components)
    }

    /// A day the banks are open: not a weekend, not a national holiday.
    /// Carnival Monday and Tuesday and Corpus Christi count as closed, the way
    /// the bank calendar does.
    static func isBusinessDay(_ day: Date, calendar: Calendar) -> Bool {
        var days = BankDays(calendar: calendar)
        return days.isOpen(day)
    }

    /// The days the banks open, with each year's holidays worked out once
    /// however many days a count walks through: "em 999 dias úteis".
    struct BankDays {
        let calendar: Calendar
        private var holidays: [Int: Set<Date>] = [:]

        init(calendar: Calendar) {
            self.calendar = calendar
        }

        mutating func isOpen(_ day: Date) -> Bool {
            let weekday = calendar.component(.weekday, from: day)
            guard weekday != 1, weekday != 7 else { return false }
            let year = calendar.component(.year, from: day)
            if holidays[year] == nil { holidays[year] = bankHolidays(in: year, calendar: calendar) }
            return !(holidays[year]?.contains(calendar.startOfDay(for: day)) ?? false)
        }
    }

    /// Where a day falls inside a period: the weekday in the period's week,
    /// the day in its month, the date in its year, the part of its month or
    /// week. `nil` when the two don't fit together.
    static func inside(_ inner: Value, span: (start: Date, end: Date?), calendar: Calendar) -> (
        start: Date, end: Date?
    )? {
        let first = span.start
        let year = calendar.component(.year, from: first)
        let month = calendar.component(.month, from: first)
        let weekday = calendar.component(.weekday, from: first)
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: first)
        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
            let lastOfMonth = lastDayOfMonth(firstOfMonth, calendar: calendar)
        else { return nil }
        func day(_ offset: Int, from start: Date?) -> Date? {
            start.flatMap { calendar.date(byAdding: .day, value: offset, to: $0) }
        }
        switch inner {
        case .weekday(let weekday, _):
            return day((weekday + 5) % 7, from: monday).map { ($0, nil) }
        case .startOfWeek, .middleOfWeek, .endOfWeek:
            let (from, to) = inner == .startOfWeek ? (0, 1) : inner == .middleOfWeek ? (2, 2) : (3, 4)
            guard let start = day(from, from: monday), let end = day(to, from: monday) else { return nil }
            return (start, start == end ? nil : end)
        case .dayOfMonth(let dayNumber):
            guard DayRules.isValidDate(day: dayNumber, month: month, year: year) else { return nil }
            return calendar.date(from: DateComponents(year: year, month: month, day: dayNumber)).map {
                ($0, nil)
            }
        case .endOfMonth(months: 0):
            return (lastOfMonth, nil)
        case .date(let dayNumber, let dateMonth, nil):
            guard DayRules.isValidDate(day: dayNumber, month: dateMonth, year: year) else { return nil }
            return calendar.date(from: DateComponents(year: year, month: dateMonth, day: dayNumber)).map {
                ($0, nil)
            }
        case .month(let named, nil):
            return resolve(.month(named, year: year), reference: first, calendar: calendar)
        case .startOfYear, .middleOfYear, .endOfYear:
            let (dateMonth, dayNumber) =
                inner == .startOfYear ? (1, 1) : inner == .middleOfYear ? (6, 30) : (12, 31)
            return calendar.date(from: DateComponents(year: year, month: dateMonth, day: dayNumber)).map {
                ($0, nil)
            }
        case .nthBusinessDayOfMonth(let place):
            var date = place > 0 ? firstOfMonth : lastOfMonth
            var left = abs(place)
            var bank = BankDays(calendar: calendar)
            while true {
                if bank.isOpen(date) {
                    left -= 1
                    if left == 0 { return (date, nil) }
                }
                guard let next = day(place > 0 ? 1 : -1, from: date),
                    calendar.isDate(next, equalTo: firstOfMonth, toGranularity: .month)
                else { return nil }
                date = next
            }
        case .nthWeekdayOfMonth(let place, let weekday):
            return nthWeekday(place, weekday, inMonthOf: firstOfMonth, calendar: calendar).map { ($0, nil) }
        case .weekOfMonth(let place):
            let start = place > 0 ? day(7 * (place - 1), from: firstOfMonth) : day(-6, from: lastOfMonth)
            guard let start, let end = day(6, from: start),
                calendar.isDate(start, equalTo: firstOfMonth, toGranularity: .month)
            else { return nil }
            return (start, min(end, lastOfMonth))
        default:
            return nil
        }
    }

    /// The national holidays the banks close on, as dates in that year.
    static func bankHolidays(in year: Int, calendar: Calendar) -> Set<Date> {
        let fixed = [(1, 1), (4, 21), (5, 1), (9, 7), (10, 12), (11, 2), (11, 15), (11, 20), (12, 25)]
        var dates = Set(
            fixed.compactMap { calendar.date(from: DateComponents(year: year, month: $0.0, day: $0.1)) })
        for offset in [-48, -47, -2, 60] {
            guard let easter = easter(in: year, calendar: calendar),
                let date = calendar.date(byAdding: .day, value: offset, to: easter)
            else { continue }
            dates.insert(date)
        }
        return dates
    }

    static func lastDayOfMonth(_ day: Date, calendar: Calendar) -> Date? {
        guard let interval = calendar.dateInterval(of: .month, for: day),
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end)
        else { return nil }
        return calendar.startOfDay(for: last)
    }

    static let daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    static func nextMonday(after day: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(after: day, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)
    }
}
