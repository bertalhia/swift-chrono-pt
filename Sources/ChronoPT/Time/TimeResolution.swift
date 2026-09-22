import Foundation

/// From the time pieces the rules found to the clock time they mean.
extension TimeRules {
    /// A time mentioned in the text, already decided: adjacent pieces ("de
    /// manhã, às 7", "à noite, lá pelas 8") become a single time.
    struct Expression: Sendable {
        let range: Range<String.Index>
        let value: Resolved
        /// Not a time on its own: "chegar cedo".
        let needsDay: Bool
        /// The pieces the time was decided from.
        let pieces: [Piece<Value>]

        /// The clock time that settled this part of the day, when it was said
        /// apart: "amanhã de manhã, reunião às 7".
        var settledRange: Range<String.Index>?

        /// The other half of the day for an hour that did not say which: 7:00
        /// for "às 7", which reads as 19:00.
        var alternative: Clock?

        /// "há 2 horas": counts only with `ChronoPT.Options.allowsPast`.
        var isPast: Bool {
            if case .fromNow(let minutes) = value { minutes < 0 } else { false }
        }

        /// A time counted from now, which belongs to no day: "daqui a 2 horas"
        /// in "consulta dia 30, sair daqui a 20 minutos".
        var isFromNow: Bool {
            if case .fromNow = value { true } else { false }
        }

        /// The time zone the text named for the clock time: "15h BRT".
        var zone: TimeZone? {
            pieces.lazy.compactMap { piece in if case .zone(let zone) = piece.value { zone } else { nil } }
                .first
        }

        /// "o dia todo": the day, with no hour.
        var isAllDay: Bool {
            if case .allDay = value { true } else { false }
        }

        /// What the time fixes; see `ChronoPT.PartialDate.knownComponents`. A clock time
        /// gives the hour and the minute, a part of the day only the hour, and
        /// a time from now the whole date.
        var knownComponents: Set<Calendar.Component> {
            zone == nil ? clockComponents : clockComponents.union([.timeZone])
        }

        private var clockComponents: Set<Calendar.Component> {
            switch value {
            case .fromNow:
                [.day, .month, .year, .hour, .minute]
            case .allDay:
                []
            case .between:
                pieces.contains { if case .span = $0.value { true } else { false } }
                    ? [.hour] : [.hour, .minute]
            case .at:
                pieces.contains { piece in
                    if case let .clock(_, _, _, _, needsEnd) = piece.value { !needsEnd } else { false }
                } ? [.hour, .minute] : [.hour]
            }
        }
    }

    /// The times mentioned in the text, in text order.
    static func expressions(
        in source: TextSource, moments: [String: Int] = [:], days: [Range<String.Index>] = [],
        claimed: [Range<String.Index>] = []
    ) -> [Expression] {
        var groups: [[Piece<Value>]] = []
        for piece in candidates(in: source, moments: moments, days: days, claimed: claimed) {
            if let group = groups.last, let last = group.last,
                source.onlyConnectors(between: last.range, and: piece.range),
                continues(group, with: piece, in: source)
            {
                groups[groups.count - 1].append(piece)
            } else {
                groups.append([piece])
            }
        }
        return groups.compactMap { group in
            guard let first = group.first, let last = group.last else { return nil }
            return range(in: group, source: source)
                ?? resolve(group, range: first.range.lowerBound..<last.range.upperBound)
        }
    }

    /// A second clock time joins a group only as the end of a range: "das
    /// 14h às 16h" is one time, "às 8h e às 20h" two.
    static func continues(_ group: [Piece<Value>], with piece: Piece<Value>, in source: TextSource) -> Bool {
        guard piece.value.isClock, let clock = group.last(where: \.value.isClock) else { return true }
        return source.rangeStart(
            from: clock.range, to: piece.range, bareStart: source.startsWithNumber(clock.range)) != nil
    }

    /// A group with two clock times joined as a range: "das 14h às 16h", "de
    /// 9 a 11h", "entre 10 e 11h", "14h às 16h", "10h-11h". Its range starts at
    /// the opening word, if there is one.
    static func range(in group: [Piece<Value>], source: TextSource) -> Expression? {
        guard let first = group.first, let last = group.last else { return nil }
        for index in group.indices.dropFirst() {
            guard case let .clock(hour, minute, ambiguous, nextDay, _) = group[index - 1].value,
                case let .clock(endHour, endMinute, endAmbiguous, endNextDay, _) = group[index].value,
                let start = source.rangeStart(
                    from: group[index - 1].range,
                    to: group[index].range,
                    bareStart: source.startsWithNumber(group[index - 1].range)
                )
            else { continue }
            let period = group.lazy.compactMap { piece -> Int? in
                if case let .period(hour, _, _) = piece.value { hour } else { nil }
            }.first
            let (from, until) = range(
                from: (hour, minute, ambiguous, nextDay),
                to: (endHour, endMinute, endAmbiguous, endNextDay),
                period: period
            )
            let range = min(start, first.range.lowerBound)..<last.range.upperBound
            return Expression(
                range: range, value: .between(from, until: until), needsDay: false, pieces: group)
        }
        return nil
    }

    /// The two ends of a time range. A part of the day settles both. Without
    /// one, the start reads as a single time would, unless the end says the
    /// half of the day ("das 7 às 9 da manhã" is 7:00 to 9:00), and an
    /// ambiguous end is the first reading after the start ("das 7 às 9" is
    /// 19:00 to 21:00). An end before the start is on the next day.
    static func range(from start: ClockPiece, to end: ClockPiece, period: Int?) -> (Clock, Clock) {
        let ends = readings(of: end, period: period)
        let single = minutes(of: start, period: period)
        let from =
            ends.count == 1 ? readings(of: start, period: period).last { $0 < ends[0] } ?? single : single
        let until = ends.first { $0 > from } ?? ends[0] + 24 * 60
        return (time(minutes: from), time(minutes: until))
    }

    typealias ClockPiece = (hour: Int, minute: Int, ambiguous: Bool, nextDay: Bool)

    /// Minutes from the start of the day. An ambiguous hour follows the part
    /// of the day or, without one, the way people speak: one to seven is
    /// afternoon or evening ("às 7" is 19:00), eight to eleven is morning.
    static func minutes(of clock: ClockPiece, period: Int?) -> Int {
        let afternoon = clock.ambiguous && (period.map { $0 >= 12 } ?? (clock.hour <= 7))
        return (clock.hour + (afternoon ? 12 : 0)) * 60 + clock.minute + (clock.nextDay ? 24 * 60 : 0)
    }

    /// Both halves of the day for an ambiguous hour with no part of the day;
    /// one reading otherwise.
    static func readings(of clock: ClockPiece, period: Int?) -> [Int] {
        guard clock.ambiguous, period == nil else { return [minutes(of: clock, period: period)] }
        let morning = clock.hour * 60 + clock.minute
        return [morning, morning + 12 * 60]
    }

    /// Minutes as a clock time; past midnight is the next day. Minutes before
    /// the hour move back from the named hour: "dez para a meia-noite" is 23:50
    /// of the same day.
    static func time(minutes: Int) -> Clock {
        Clock(hour: minutes / 60 % 24, minute: minutes % 60, dayOffset: minutes / (24 * 60))
    }

    /// A part of the day next to the day and a clock time said further on make
    /// one time when both fall in the same half of the day: "amanhã de manhã,
    /// reunião às 7" is 7:00, while "amanhã de manhã, jantar às 19h" stays at
    /// 9:00. The range stays the part of the day's.
    static func joining(_ partOfDay: Expression, _ clock: Expression) -> Expression? {
        guard case .at = clock.value,
            partOfDay.pieces.allSatisfy(\.value.isPeriod),
            clock.pieces.allSatisfy(\.value.isClock),
            case .at(let period) = partOfDay.value,
            let joined = resolve(partOfDay.pieces + clock.pieces, range: partOfDay.range),
            case .at(let time) = joined.value,
            (time.hour >= 12) == (period.hour >= 12)
        else { return nil }
        var settled = joined
        settled.settledRange = clock.range
        return settled
    }

    /// Time from now beats everything; a clock time beats a part of the day,
    /// and the part of the day settles a clock time that doesn't say morning
    /// or evening: "de manhã, às 7" is 7:00. A whole part of the day beats the
    /// whole day, and both beat a part of the day.
    static func resolve(_ group: [Piece<Value>], range: Range<String.Index>) -> Expression? {
        var clock: ClockPiece?
        var period: (hour: Int, minute: Int, needsDay: Bool)?
        var span: (from: Int, until: Int)?
        var allDay = false

        for piece in group {
            switch piece.value {
            case .fromNow(let minutes):
                return Expression(
                    range: range, value: .fromNow(minutes: minutes), needsDay: false, pieces: group)
            case let .clock(hour, minute, ambiguous, nextDay, needsEnd):
                if clock == nil, !needsEnd { clock = (hour, minute, ambiguous, nextDay) }
            case let .period(hour, minute, needsDay):
                if period == nil { period = (hour, minute, needsDay) }
            case let .span(from, until):
                if span == nil { span = (from, until) }
            case .allDay:
                allDay = true
            case .zone:
                break
            }
        }

        if let clock {
            let chosen = minutes(of: clock, period: period?.hour)
            var expression = Expression(
                range: range, value: .at(time(minutes: chosen)), needsDay: false, pieces: group)
            if clock.ambiguous, period == nil {
                expression.alternative = time(
                    minutes: chosen >= 12 * 60 ? chosen - 12 * 60 : chosen + 12 * 60)
            }
            return expression
        }
        if let span {
            return Expression(
                range: range,
                value: .between(Clock(hour: span.from, minute: 0), until: time(minutes: span.until * 60)),
                needsDay: false, pieces: group)
        }
        if allDay {
            return Expression(range: range, value: .allDay, needsDay: true, pieces: group)
        }
        if let period {
            return Expression(
                range: range, value: .at(Clock(hour: period.hour, minute: period.minute)),
                needsDay: period.needsDay, pieces: group)
        }
        return nil
    }
}
