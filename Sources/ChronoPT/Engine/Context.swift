import Foundation

/// What `parse` and `interpret` share: the text, read only once.
struct Context {
    let source: TextSource
    let days: [Piece<DayRules.Value>]
    let times: [TimeRules.Expression]
    let reference: Date
    let calendar: Calendar
    let options: ChronoPT.Options

    init(
        text: String, reference: Date, calendar: Calendar, options: ChronoPT.Options, skipsRules: Bool = true
    ) {
        source = TextSource(text, skipsRules: skipsRules)
        let calendar = Self.gregorian(like: calendar)
        let times = TimeRules.expressions(in: source, moments: options.moments)
        let days = DayRules.expressions(in: source, times: times, reference: reference, calendar: calendar)
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

    /// Whether a time can go with this day. A time counted from now belongs to
    /// no day, unless it lands on this one: "hoje mais tarde" is two hours
    /// from now, "consulta dia 30, sair daqui a 20 minutos" is the 30th.
    func fits(_ time: TimeRules.Expression, with day: Piece<DayRules.Value>) -> Bool {
        guard case .fromNow(let minutes) = time.value else { return true }
        guard let days = resolve(day), days.end == nil else { return false }
        return calendar.isDate(reference.addingTimeInterval(Double(minutes) * 60), inSameDayAs: days.start)
    }

    /// The rules are Gregorian: month names, weekday names, holidays and the
    /// Easter computus all count Gregorian years. A caller who passes another
    /// calendar keeps its time zone, and the arithmetic runs in Gregorian, so
    /// "25/09/2026" is the same instant either way.
    private static func gregorian(like calendar: Calendar) -> Calendar {
        guard calendar.identifier != .gregorian, calendar.identifier != .iso8601 else { return calendar }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        gregorian.locale = calendar.locale
        return gregorian
    }

    func resolve(_ day: Piece<DayRules.Value>, from reference: Date? = nil) -> (start: Date, end: Date?)? {
        DayRules.resolve(day.value, reference: reference ?? self.reference, calendar: calendar)
    }

    /// Joins a day and a time; either one may be missing. A repeating date is
    /// the next time it happens: "toda segunda às 9" said on a Monday at 10:00
    /// is next Monday.
    func combine(_ day: Piece<DayRules.Value>?, _ time: TimeRules.Expression?) -> ChronoPT.Match? {
        guard let day, day.value.recurrence != nil,
            let found = combine(day, time, from: reference), found.start.date < reference
        else {
            return combine(day, time, from: reference)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))
        return tomorrow.flatMap { combine(day, time, from: $0) } ?? found
    }

    private func combine(
        _ day: Piece<DayRules.Value>?, _ time: TimeRules.Expression?, from dayReference: Date
    ) -> ChronoPT.Match? {
        // A full date and time names its moment; a time next to it adds nothing.
        if let day, case .dateTime = day.value {
            guard let date = DayRules.instant(of: day.value, calendar: calendar) else { return nil }
            let start = ChronoPT.PartialDate(date: date, knownComponents: day.value.knownComponents)
            return result(start, end: nil, range: day.range)
        }
        // An interval of hours counts from now, not from a day: "de 8 em 8 horas".
        if let day, time == nil, case .interval(let components) = day.value,
            components.hour != nil || components.minute != nil
        {
            guard let date = calendar.date(byAdding: components, to: reference) else { return nil }
            let start = ChronoPT.PartialDate(
                date: date, knownComponents: [.day, .month, .year, .hour, .minute])
            return result(
                start, end: nil, range: day.range, recurrence: recurrence(of: day.value, from: date))
        }
        if let day {
            guard let days = resolve(day, from: dayReference) else { return nil }
            let recurrence = self.recurrence(of: day.value, from: days.start)
            guard let time else {
                guard let start = dayOnly(days.start) else { return nil }
                return result(
                    ChronoPT.PartialDate(date: start, knownComponents: day.value.knownComponents),
                    end: days.end.flatMap(dayOnly).map {
                        ChronoPT.PartialDate(date: $0, knownComponents: day.value.endKnownComponents)
                    },
                    range: day.range,
                    recurrence: recurrence
                )
            }
            let date: Date?
            let end: Date?
            var alternative: Date?
            switch time.value {
            case .fromNow(let minutes):
                date = reference.addingTimeInterval(Double(minutes) * 60)
                end = nil
            case .at(let clock):
                date = clock.on(days.start, calendar: calendar)
                end = days.end.flatMap { clock.on($0, calendar: calendar) }
                alternative = time.alternative.flatMap { $0.on(days.start, calendar: calendar) }
            case .between(let start, let until):
                date = start.on(days.start, calendar: calendar)
                end = until.on(days.end ?? days.start, calendar: calendar)
            case .allDay:
                // The whole day has no hour to give: the day as if alone.
                date = dayOnly(days.start)
                end = days.end.flatMap(dayOnly)
            }
            guard let date else { return nil }
            // A day and a time next to each other come out together; apart,
            // the day carries the match and the time keeps a span of its own.
            let adjacent = source.onlyConnectors(between: day.range, and: time.range)
            let range =
                adjacent
                ? min(
                    day.range.lowerBound, time.range.lowerBound)..<max(
                        day.range.upperBound, time.range.upperBound)
                : day.range
            let spans = [range] + [adjacent ? nil : time.range, time.settledRange].compactMap { $0 }
            let ranges = spans.sorted { $0.lowerBound < $1.lowerBound }
            return result(
                ChronoPT.PartialDate(
                    date: date, knownComponents: day.value.knownComponents.union(time.knownComponents),
                    alternative: alternative),
                end: end.map {
                    ChronoPT.PartialDate(
                        date: $0, knownComponents: day.value.endKnownComponents.union(time.knownComponents))
                },
                range: range,
                ranges: ranges,
                recurrence: recurrence,
                isAllDay: time.isAllDay
            )
        }

        guard let time, !time.needsDay else { return nil }
        let known = time.knownComponents
        switch time.value {
        case .fromNow(let minutes):
            let date = reference.addingTimeInterval(Double(minutes) * 60)
            return result(
                ChronoPT.PartialDate(date: date, knownComponents: known), end: nil, range: time.range)
        case .at(let clock):
            guard let day = upcomingDay(for: clock), let date = clock.on(day, calendar: calendar) else {
                return nil
            }
            // The other reading's next time: "às 7" at 10:00 is 19:00 today,
            // or 7:00 tomorrow.
            let alternative = time.alternative.flatMap { other in
                upcomingDay(for: other).flatMap { other.on($0, calendar: calendar) }
            }
            return result(
                ChronoPT.PartialDate(date: date, knownComponents: known, alternative: alternative), end: nil,
                range: time.range)
        case .between(let start, let until):
            guard let day = upcomingDay(for: start), let date = start.on(day, calendar: calendar) else {
                return nil
            }
            let end = until.on(day, calendar: calendar).map {
                ChronoPT.PartialDate(date: $0, knownComponents: known)
            }
            return result(
                ChronoPT.PartialDate(date: date, knownComponents: known), end: end, range: time.range)
        case .allDay:
            // Needs a day, and the guard above saw it has none.
            return nil
        }
    }

    /// How the day repeats, with the end the text gave: "toda terça até
    /// dezembro" stops at the end of 31 December, and "todo dia por 10 dias"
    /// at the end of the tenth day from the first.
    private func recurrence(of value: DayRules.Value, from first: Date) -> ChronoPT.Recurrence? {
        guard var recurrence = value.recurrence else { return nil }
        guard case .repeating(_, let limit) = value else { return recurrence }
        switch limit {
        case .count(let count):
            recurrence.end = .count(count)
        case .day(let last):
            let days = DayRules.resolve(last, reference: reference, calendar: calendar)
            recurrence.end = endOfDay(days.map { $0.end ?? $0.start }).map { .until($0) }
        case .length(let length):
            let after = calendar.date(byAdding: length, to: calendar.startOfDay(for: first))
            recurrence.end = endOfDay(after.flatMap { calendar.date(byAdding: .day, value: -1, to: $0) })
                .map { .until($0) }
        }
        return recurrence
    }

    /// The last second of the day.
    private func endOfDay(_ day: Date?) -> Date? {
        day.flatMap {
            calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: $0))
        }
    }

    /// Time only: today, or tomorrow if that time has passed.
    private func upcomingDay(for clock: TimeRules.Clock) -> Date? {
        guard let today = clock.on(reference, calendar: calendar) else { return nil }
        return today > reference ? reference : calendar.date(byAdding: .day, value: 1, to: reference)
    }

    /// A day with no time: noon, or `ChronoPT.Options.defaultHour`.
    private func dayOnly(_ day: Date) -> Date? {
        calendar.date(bySettingHour: options.defaultHour, minute: 0, second: 0, of: day)
    }

    private func result(
        _ start: ChronoPT.PartialDate,
        end: ChronoPT.PartialDate?,
        range: Range<String.Index>,
        ranges: [Range<String.Index>]? = nil,
        recurrence: ChronoPT.Recurrence? = nil,
        isAllDay: Bool = false
    ) -> ChronoPT.Match {
        let original = source.originalRange(range)
        return ChronoPT.Match(
            range: original,
            ranges: (ranges ?? [range]).map(source.originalRange),
            text: String(source.original[original]),
            start: start,
            end: end,
            recurrence: recurrence,
            isAllDay: isAllDay
        )
    }
}
