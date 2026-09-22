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

        case .months(let count):
            return calendar.date(byAdding: .month, value: count, to: today).map { ($0, nil) }

        case .weekday(let weekday, let nextWeek):
            if nextWeek {
                // Next week runs Monday to Sunday.
                guard let monday = nextMonday(after: today, calendar: calendar) else { return nil }
                return calendar.date(byAdding: .day, value: (weekday + 5) % 7, to: monday).map { ($0, nil) }
            }
            // The next time that weekday comes, not counting today: "sexta"
            // said on a Friday is next week's.
            return calendar.nextDate(after: today, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime)
                .map { ($0, nil) }

        case .date(let day, let month, let year):
            guard (1...12).contains(month), (1...daysInMonth[month - 1]).contains(day) else { return nil }
            if let year {
                let components = DateComponents(year: year, month: month, day: day)
                // The calendar rolls a date that doesn't exist over (29/02 in a
                // common year becomes 01/03); then it is not a date.
                guard let date = calendar.date(from: components),
                      calendar.component(.day, from: date) == day else { return nil }
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

        case .thisWeek:
            // From today to Sunday; on a Sunday, just today.
            let weekday = calendar.component(.weekday, from: today)
            guard weekday != 1 else { return (today, nil) }
            return calendar.date(byAdding: .day, value: 8 - weekday, to: today).map { (today, $0) }

        case .nextWeek:
            guard let monday = nextMonday(after: today, calendar: calendar),
                  let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return nil }
            return (monday, sunday)

        case .weekend(let weeks):
            let weekday = calendar.component(.weekday, from: today)
            // On Saturday it is this weekend; on Sunday, what is left of it.
            if weeks == 0, weekday == 1 { return (today, nil) }
            let coming = weekday == 7
                ? today
                : calendar.nextDate(after: today, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime)
            guard let coming,
                  let saturday = calendar.date(byAdding: .day, value: 7 * weeks, to: coming),
                  let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) else { return nil }
            return (saturday, sunday)

        case .thisMonth:
            // From today to the last day; on the last day, just today.
            guard let last = lastDayOfMonth(today, calendar: calendar) else { return nil }
            return (today, last == today ? nil : last)

        case .nextMonth:
            guard let first = firstDayOfNextMonth(today, calendar: calendar),
                  let last = lastDayOfMonth(first, calendar: calendar) else { return nil }
            return (first, last)

        case .startOfNextMonth:
            return firstDayOfNextMonth(today, calendar: calendar).map { ($0, nil) }

        case .nextYear:
            guard let thisYear = calendar.dateInterval(of: .year, for: today)?.start,
                  let first = calendar.date(byAdding: .year, value: 1, to: thisYear),
                  let last = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: first) else { return nil }
            return (first, last)

        case .endOfMonth(let months):
            guard let month = calendar.date(byAdding: .month, value: months, to: today) else { return nil }
            return lastDayOfMonth(month, calendar: calendar).map { ($0, nil) }

        case .lastWeekday(let weekday):
            return calendar.nextDate(
                after: today,
                matching: DateComponents(weekday: weekday),
                matchingPolicy: .nextTime,
                direction: .backward
            ).map { ($0, nil) }

        case .lastWeek:
            // Monday to Sunday of the week before this one.
            let weekday = calendar.component(.weekday, from: today)
            guard let thisMonday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today),
                  let monday = calendar.date(byAdding: .day, value: -7, to: thisMonday),
                  let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return nil }
            return (monday, sunday)

        case .lastMonth:
            guard let thisMonth = calendar.dateInterval(of: .month, for: today)?.start,
                  let first = calendar.date(byAdding: .month, value: -1, to: thisMonth),
                  let last = lastDayOfMonth(first, calendar: calendar) else { return nil }
            return (first, last)

        case .lastYear:
            guard let thisYear = calendar.dateInterval(of: .year, for: today)?.start,
                  let first = calendar.date(byAdding: .year, value: -1, to: thisYear),
                  let last = calendar.date(byAdding: .day, value: -1, to: thisYear) else { return nil }
            return (first, last)

        case .daily, .interval:
            return (today, nil)

        case .weekly(let weekdays):
            // The next of these weekdays, counting today.
            return weekdays.compactMap { weekday in
                calendar.nextDate(
                    after: today.addingTimeInterval(-1),
                    matching: DateComponents(weekday: weekday),
                    matchingPolicy: .nextTime
                )
            }.min().map { ($0, nil) }

        case .monthly(let day):
            return resolve(.dayOfMonth(day), reference: reference, calendar: calendar)

        case .range(let from, let to):
            // The end is the first time `to` comes from the start on: "de
            // segunda a sexta" said on a Monday runs from next Monday to that
            // Friday.
            guard let first = resolve(from, reference: reference, calendar: calendar),
                  var last = resolve(to, reference: reference, calendar: calendar) else { return nil }
            if (last.end ?? last.start) < first.start, let later = resolve(to, reference: first.start, calendar: calendar) {
                last = later
            }
            let end = last.end ?? last.start
            return end > first.start ? (first.start, end) : first

        case .holiday(let holiday):
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
                  let start = calendar.date(byAdding: .day, value: offset, to: easter) else { return nil }
            return (start, lastDay.flatMap { calendar.date(byAdding: .day, value: $0, to: easter) })
        case .secondSunday(let month):
            guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
            let firstSunday = (8 - calendar.component(.weekday, from: first)) % 7
            return calendar.date(byAdding: .day, value: firstSunday + 7, to: first).map { ($0, nil) }
        }
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

    static func firstDayOfNextMonth(_ day: Date, calendar: Calendar) -> Date? {
        guard let thisMonth = calendar.dateInterval(of: .month, for: day)?.start else { return nil }
        return calendar.date(byAdding: .month, value: 1, to: thisMonth)
    }

    static func lastDayOfMonth(_ day: Date, calendar: Calendar) -> Date? {
        guard let interval = calendar.dateInterval(of: .month, for: day),
              let last = calendar.date(byAdding: .day, value: -1, to: interval.end) else { return nil }
        return calendar.startOfDay(for: last)
    }

    static let daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    static func nextMonday(after day: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(after: day, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)
    }
}
