import Foundation

/// What `parse` and `interpret` share: the text, read only once.
struct Context {
    let source: TextSource
    let days: [Piece<DayRules.Value>]
    let times: [TimeRules.Expression]
    let reference: Date
    let calendar: Calendar
    let options: ParseOptions

    init(text: String, reference: Date, calendar: Calendar, options: ParseOptions) {
        source = TextSource(text)
        let times = TimeRules.expressions(in: source)
        let days = DayRules.expressions(in: source, times: times)
        if options.allowsPast {
            self.times = times
            self.days = days
        } else {
            // Past words still claim their text, so "sexta passada" never reads
            // as next Friday; then they drop out, with any time next to them.
            let past = days.filter(\.value.isPast)
            self.days = days.filter { !$0.value.isPast }
            self.times = times.filter { [source] time in
                !time.isPast && !past.contains { source.onlyConnectors(between: $0.range, and: time.range) }
            }
        }
        self.reference = reference
        self.calendar = calendar
        self.options = options
    }

    func resolve(_ day: Piece<DayRules.Value>, from reference: Date? = nil) -> (start: Date, end: Date?)? {
        DayRules.resolve(day.value, reference: reference ?? self.reference, calendar: calendar)
    }

    /// Joins a day and a time; either one may be missing. A repeating date is
    /// the next time it happens: "toda segunda às 9" said on a Monday at 10:00
    /// is next Monday.
    func combine(_ day: Piece<DayRules.Value>?, _ time: TimeRules.Expression?) -> ParsedResult? {
        guard let day, day.value.recurrence != nil,
              let found = combine(day, time, from: reference), found.start.date < reference else {
            return combine(day, time, from: reference)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))
        return tomorrow.flatMap { combine(day, time, from: $0) } ?? found
    }

    private func combine(_ day: Piece<DayRules.Value>?, _ time: TimeRules.Expression?, from dayReference: Date) -> ParsedResult? {
        // An interval of hours counts from now, not from a day: "de 8 em 8 horas".
        if let day, time == nil, case .interval(let components) = day.value, components.hour != nil || components.minute != nil {
            guard let date = calendar.date(byAdding: components, to: reference) else { return nil }
            let start = ParsedDate(date: date, knownComponents: [.day, .month, .year, .hour, .minute])
            return result(start, end: nil, range: day.range, recurrence: day.value.recurrence)
        }
        if let day {
            guard let days = resolve(day, from: dayReference) else { return nil }
            let recurrence = day.value.recurrence
            guard let time else {
                guard let start = dayOnly(days.start) else { return nil }
                return result(
                    ParsedDate(date: start, knownComponents: day.value.knownComponents),
                    end: days.end.flatMap(dayOnly).map { ParsedDate(date: $0, knownComponents: day.value.endKnownComponents) },
                    range: day.range,
                    recurrence: recurrence
                )
            }
            let date: Date?
            let end: Date?
            switch time.value {
            case .fromNow(let minutes):
                date = reference.addingTimeInterval(Double(minutes) * 60)
                end = nil
            case .at(let clock):
                date = clock.on(days.start, calendar: calendar)
                end = days.end.flatMap { clock.on($0, calendar: calendar) }
            case .between(let start, let until):
                date = start.on(days.start, calendar: calendar)
                end = until.on(days.end ?? days.start, calendar: calendar)
            }
            guard let date else { return nil }
            // A day and a time next to each other come out together; apart, only the day.
            let range = source.onlyConnectors(between: day.range, and: time.range)
                ? min(day.range.lowerBound, time.range.lowerBound)..<max(day.range.upperBound, time.range.upperBound)
                : day.range
            return result(
                ParsedDate(date: date, knownComponents: day.value.knownComponents.union(time.knownComponents)),
                end: end.map { ParsedDate(date: $0, knownComponents: day.value.endKnownComponents.union(time.knownComponents)) },
                range: range,
                recurrence: recurrence
            )
        }

        guard let time, !time.needsDay else { return nil }
        let known = time.knownComponents
        switch time.value {
        case .fromNow(let minutes):
            let date = reference.addingTimeInterval(Double(minutes) * 60)
            return result(ParsedDate(date: date, knownComponents: known), end: nil, range: time.range)
        case .at(let clock):
            guard let day = upcomingDay(for: clock), let date = clock.on(day, calendar: calendar) else { return nil }
            return result(ParsedDate(date: date, knownComponents: known), end: nil, range: time.range)
        case .between(let start, let until):
            guard let day = upcomingDay(for: start), let date = start.on(day, calendar: calendar) else { return nil }
            let end = until.on(day, calendar: calendar).map { ParsedDate(date: $0, knownComponents: known) }
            return result(ParsedDate(date: date, knownComponents: known), end: end, range: time.range)
        }
    }

    /// Time only: today, or tomorrow if that time has passed.
    private func upcomingDay(for clock: TimeRules.Clock) -> Date? {
        guard let today = clock.on(reference, calendar: calendar) else { return nil }
        return today > reference ? reference : calendar.date(byAdding: .day, value: 1, to: reference)
    }

    /// A day with no time: noon, or `ParseOptions.defaultHour`.
    private func dayOnly(_ day: Date) -> Date? {
        calendar.date(bySettingHour: options.defaultHour, minute: 0, second: 0, of: day)
    }

    private func result(
        _ start: ParsedDate,
        end: ParsedDate?,
        range: Range<String.Index>,
        recurrence: Recurrence? = nil
    ) -> ParsedResult {
        let original = source.originalRange(range)
        return ParsedResult(
            range: original,
            text: String(source.original[original]),
            start: start,
            end: end,
            recurrence: recurrence
        )
    }
}
