import Foundation

/// Day rules: "hoje", "amanhã", "sexta que vem", "25/09", "15 de outubro",
/// "dia 30", "daqui 2 dias", "esta semana", "fim de semana", "ano que vem".
///
/// Past days ("ontem") are left out on purpose: the date becomes a reminder,
/// and a reminder in the past is useless.
///
/// A weekday name that is also an ordinal ("segunda via", "quinta série") only
/// counts with a hint that it is a day: "na segunda", "segunda-feira", "sexta
/// que vem", or a time right after it ("sexta às 10", "quarta à noite").
/// Saturday and Sunday have no other meaning and count on their own.
///
/// Holiday names with another meaning ("Natal" is also a city, "ovo de
/// páscoa" is chocolate) count only after a preposition: "no natal", "na
/// páscoa", "feriado de tiradentes".
enum DayRules {
    struct Candidate {
        let piece: Piece<Value>
        /// Counts only with a time right after it ("quinta às 10").
        let hint: Hint

        /// What a candidate needs before it counts.
        enum Hint {
            /// Nothing: "amanhã", "25/09".
            case none
            /// A time next to it, a range or its date: "quinta às 10".
            case time
            /// A bigger expression that counts from it: "natal" in "dois dias
            /// antes do natal". Alone it is not a date.
            case anchor
            /// A date on the calendar: "sexta, 25" only when the 25th is a
            /// Friday. Checked before overlaps are removed, so a pair that
            /// disagrees leaves the weekday alone: "na quinta, 25".
            case date
        }
    }

    /// The days mentioned in the text, without overlap, in text order.
    static func expressions(
        in source: TextSource, found: [Candidate], times: [TimeRules.Expression], reference: Date,
        calendar: Calendar
    ) -> [Piece<Value>] {
        let near = Neighbours(found)
        let candidates =
            (found + ranges(of: near, in: source, times: times) + weekdaysWithDates(of: near, in: source)
            + datesWithWeekdays(of: near, in: source) + weeklyEvery(of: near, in: source)
            + offsets(of: near, in: source) + lengths(of: near, in: source)
            + limits(of: near, in: source, times: times) + withins(of: near, in: source))
            .filter { candidate in
                switch candidate.hint {
                case .none: return true
                case .anchor: return false
                case .date:
                    return resolve(candidate.piece.value, reference: reference, calendar: calendar) != nil
                case .time: break
                }
                // Only the times right before and right after can be next to
                // it: any other has one of those two in between.
                let after = firstIndex(in: times, from: candidate.piece.range.upperBound) {
                    $0.range.lowerBound
                }
                return times[max(0, after - 1)..<min(times.count, after + 1)].contains { time in
                    guard !time.isFromNow else { return false }
                    guard source.onlyConnectors(between: candidate.piece.range, and: time.range) else {
                        return false
                    }
                    // A time before the day only counts with "de": "às 10 de
                    // quinta" is Thursday, but "às 10 segunda via" is not Monday.
                    return time.range.lowerBound >= candidate.piece.range.lowerBound
                        || source.word(before: candidate.piece.range.lowerBound) == "de"
                }
            }
        return Piece.nonOverlapping(candidates.map(\.piece), in: source)
    }

    /// Two days joined as a range: "de segunda a sexta", "do dia 10 ao dia
    /// 15", "de hoje até sexta", "segunda a sexta", "seg-sex". The range is the
    /// hint a weekday needs. With no opening word, the first day has to start
    /// right at its number or name.
    private static func ranges(of near: Neighbours, in source: TextSource, times: [TimeRules.Expression])
        -> [Candidate]
    {
        let sorted = near.byStart
        return sorted.indices.flatMap { index -> [Candidate] in
            let first = sorted[index]
            let firstWord = source.words(after: first.piece.range.lowerBound, count: 1).first ?? ""
            let bareStart = source.startsWithNumber(first.piece.range) || weekdays[firstWord] != nil
            guard let opening = source.rangeOpening(of: first.piece.range, bareStart: bareStart) else {
                return []
            }
            var found: [Candidate] = []
            // Ends in text order; once the gap holds a word no range allows,
            // no later end can close this range.
            for second in sorted[(index + 1)...]
            where second.piece.range.lowerBound >= first.piece.range.upperBound {
                // A time may sit inside: "de segunda às 14h até sexta às 18h".
                guard
                    let closes = source.closesRange(
                        opening, from: first.piece.range, to: second.piece.range,
                        skipping: { isInsideTime($0.startIndex, times, in: source) })
                else { break }
                guard closes else { continue }
                // A day of the month takes the month of the end: "do dia 10 ao
                // dia 15 de novembro".
                var from = first.piece.value
                if case .dayOfMonth(let day) = from, case let .date(last, month, year) = second.piece.value,
                    day <= last
                {
                    from = .date(day: day, month: month, year: year)
                }
                // Both days are in the week the end names: "de quarta a sexta
                // da semana que vem".
                if case .weekday(let day, nil) = from, case .weekday(_, let week?) = second.piece.value {
                    from = .weekday(day, week: week)
                }
                let piece = Piece(
                    range: opening.start..<second.piece.range.upperBound,
                    value: Value.range(from, second.piece.value))
                found.append(Candidate(piece: piece, hint: merged(first, second)))
            }
            return found
        }
    }

    /// A bare "d/m" that counts or scores something: "24/7", "tirei 8/10",
    /// "1/2 xícara", "2/3 da turma". A date after "dia" or with a year is
    /// always a date; otherwise a noun after it, or a score word before it,
    /// makes it a number.
    static func isFraction(_ range: Range<String.Index>, in source: TextSource) -> Bool {
        let text = source.normalized[range]
        if text.hasPrefix("dia ") { return false }
        if text == "24/7" { return true }
        if let before = source.word(before: range.lowerBound), scoreWords.contains(before) { return true }
        let next = source.words(after: range.upperBound, count: 2)
        // A time or a weekday after it makes it a date: "25/09 14h", "28/9
        // (seg)", "02/10 sexta-feira".
        guard let first = next.first, first.first?.isNumber != true, weekdays[first] == nil, first != "ter"
        else { return false }
        if ["de", "da", "do", "das", "dos"].contains(first) {
            return !(next.count > 1 && TimeRules.partsOfDay.contains(next[1]))
        }
        return !source.endsPhrase(at: range.upperBound)
    }

    /// A weekday name that ends a phrase is a day: "dentista terça", "ligar
    /// sexta pro João", "sexta!". An article or "em" before it makes it an
    /// ordinal ("a segunda", "ficou em segunda"), and an abbreviation keeps
    /// needing a hint ("sex" is a word).
    static func standsAlone(_ name: String, _ range: Range<String.Index>, in source: TextSource) -> Bool {
        guard fullWeekdayNames.contains(name) else { return false }
        if let before = source.word(before: range.lowerBound), wordsBeforeOrdinal.contains(before) {
            return false
        }
        guard let next = source.words(after: range.upperBound, count: 1).first else { return true }
        return wordsAfterDay.contains(next) || source.punctuationFollows(range.upperBound)
    }

    /// Whether the words after a weekday name make it an ordinal: "segunda
    /// fase", "quartas de final".
    static func isOrdinal(_ range: Range<String.Index>, in source: TextSource) -> Bool {
        let next = source.words(after: range.upperBound, count: 2)
        return next.first.map(ordinalNouns.contains) ?? false || next == ["de", "final"]
    }

    /// Whether the day exists in that month and year: not 30/02, not 31/04.
    static func isValidDate(day: Int, month: Int, year: Int) -> Bool {
        guard (1...12).contains(month), day >= 1 else { return false }
        let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        return day <= (month == 2 ? (leap ? 29 : 28) : daysInMonth[month - 1])
    }

    /// Chat spelling as the tables write it: "semana q vem" is "semana que
    /// vem", and "prox.  semana" has one space.
    static func chat(_ text: Substring) -> String {
        text.split(separator: " ").joined(separator: " ").replacingOccurrences(of: " q vem", with: " que vem")
    }

    /// A day in the month the words after it name: none for this month's,
    /// "do mês que vem", or a month by name with its year.
    private static func inMonth(_ inner: Value, next: Substring?, named: Substring?, year: Substring?)
        -> Value
    {
        if next != nil { return .within(inner, .nextMonth) }
        if let named, let month = months[String(named)] {
            return .within(inner, .month(month, year: year.flatMap { Int($0) }))
        }
        return inner
    }

    /// A day next to the period it falls in, in either order: "semana que
    /// vem, na quarta", "quarta da semana que vem", "dia 25 do mês que vem",
    /// "em outubro, dia 5", "dia 20 de outubro do ano que vem".
    private static func withins(of near: Neighbours, in source: TextSource) -> [Candidate] {
        near.byStart.flatMap { inner -> [Candidate] in
            guard nests(inner.piece.value) else { return [] }
            let after = near.starting(from: inner.piece.range.upperBound).prefix { outer in
                source.onlyConnectors(between: inner.piece.range, and: outer.piece.range)
            }
            let before = near.ending(by: inner.piece.range.lowerBound).prefix { outer in
                source.onlyConnectors(between: outer.piece.range, and: inner.piece.range)
            }
            return (Array(after) + Array(before)).compactMap { outer in
                guard holds(outer.piece.value, inner.piece.value) else { return nil }
                let range =
                    min(
                        inner.piece.range.lowerBound, outer.piece.range.lowerBound)..<max(
                        inner.piece.range.upperBound, outer.piece.range.upperBound)
                let piece = Piece(
                    range: range, value: Value.within(inner.piece.value, outer.piece.value), priority: 1)
                return Candidate(piece: piece, hint: .none)
            }
        }
    }

    /// The days that can sit inside a period.
    private static func nests(_ value: Value) -> Bool {
        switch value {
        case .weekday(_, nil), .dayOfMonth, .date(_, _, nil), .month(_, nil): true
        default: false
        }
    }

    /// Whether the period can hold the day: a week holds a weekday, a month
    /// a day of the month, a year a date or a month.
    private static func holds(_ outer: Value, _ inner: Value) -> Bool {
        switch (inner, outer) {
        case (.weekday, .nextWeek), (.weekday, .thisWeek), (.weekday, .lastWeek), (.weekday, .weeks):
            true
        case (.dayOfMonth, .nextMonth), (.dayOfMonth, .thisMonth), (.dayOfMonth, .lastMonth),
            (.dayOfMonth, .month), (.dayOfMonth, .months):
            true
        case (.date, .nextYear), (.date, .lastYear), (.date, .years), (.month, .nextYear),
            (.month, .lastYear),
            (.month, .years):
            true
        default:
            false
        }
    }

    /// A joined candidate needs its date when a part did: a range ending on
    /// "sábado, 12" that is not a Saturday gives way to "de quinta a sábado".
    private static func merged(_ first: Candidate, _ second: Candidate) -> Candidate.Hint {
        first.hint == .date || second.hint == .date ? .date : .none
    }

    /// Seconds east of UTC for "z", "-03:00" or "+0100".
    private static func offset(_ zone: Substring) -> Int? {
        if zone == "z" { return 0 }
        let digits = zone.dropFirst().filter(\.isNumber)
        guard digits.count == 4, let hours = Int(digits.prefix(2)), let minutes = Int(digits.suffix(2)),
            hours <= 14, minutes <= 59
        else {
            return nil
        }
        return (zone.first == "-" ? -1 : 1) * (hours * 3600 + minutes * 60)
    }

    /// A day counted from another: "dois dias antes do natal", "uma semana
    /// depois do dia 10", "véspera do ano novo". The day it counts from sits
    /// right after the lead, and is the hint a holiday name needs.
    private static func offsets(of near: Neighbours, in source: TextSource) -> [Candidate] {
        source.matches(of: offsetLead, whenAny: offsetWords).flatMap { lead -> [Candidate] in
            let (_, countText, unit, direction, eve) = lead.output
            let shift: DateComponents
            if let eve {
                shift = DateComponents(day: eve == "antevespera" ? -2 : -1)
            } else {
                guard let countText, let unit, let direction, let count = SpokenNumber.value(countText) else {
                    return []
                }
                shift = components(direction == "antes" ? -count : count, unit: unit)
            }
            var found: [Candidate] = []
            for base in near.starting(from: lead.range.upperBound) {
                guard source.hasNoWord(in: lead.range.upperBound..<base.piece.range.lowerBound) else { break }
                let range = lead.range.lowerBound..<base.piece.range.upperBound
                let piece = Piece(
                    range: range, value: Value.shifted(base.piece.value, by: shift), priority: 1)
                found.append(Candidate(piece: piece, hint: base.hint == .date ? .date : .none))
            }
            return found
        }
    }

    /// A day followed by how long: "amanhã por 3 dias", "sexta, por uma
    /// semana". The length is the hint a weekday needs. A repeating day keeps
    /// its own reading: "todo dia por 10 dias" is not a span.
    private static func lengths(of near: Neighbours, in source: TextSource) -> [Candidate] {
        near.byStart.flatMap { length -> [Candidate] in
            guard case .lasting(.days(0), let components) = length.piece.value else { return [] }
            var found: [Candidate] = []
            for base in near.ending(by: length.piece.range.lowerBound) {
                guard source.hasNoWord(in: base.piece.range.upperBound..<length.piece.range.lowerBound) else {
                    break
                }
                guard base.piece.value.recurrence == nil else { continue }
                let range = base.piece.range.lowerBound..<length.piece.range.upperBound
                let piece = Piece(range: range, value: Value.lasting(base.piece.value, for: components))
                found.append(Candidate(piece: piece, hint: base.hint == .date ? .date : .none))
            }
            return found
        }
    }

    /// A repeating day and where it stops: "toda terça até dezembro", "todo
    /// dia por 10 dias", "toda segunda, 5 vezes". A time may sit between the
    /// two: "toda terça às 20h até dezembro".
    private static func limits(
        of near: Neighbours, in source: TextSource, times: [TimeRules.Expression]
    ) -> [Candidate] {
        let repeating = near.byStart.filter { $0.piece.value.recurrence != nil }
        guard !repeating.isEmpty else { return [] }

        // Whether the gap after the repeating day says "até", when it holds
        // only that, articles and times; nil when it holds anything else.
        func saysUntil(after base: Candidate, before start: String.Index) -> Bool? {
            guard base.piece.range.upperBound <= start else { return nil }
            var saysUntil = false
            let joins = source.everyWord(in: base.piece.range.upperBound..<start) { word in
                if word == "ate" {
                    saysUntil = true
                    return true
                }
                return ["o", "a", "os", "as"].contains(word)
                    || isInsideTime(word.startIndex, times, in: source)
            }
            return joins ? saysUntil : nil
        }

        func joined(_ base: Candidate, _ end: Range<String.Index>, _ limit: Limit) -> Candidate {
            let piece = Piece(
                range: base.piece.range.lowerBound..<end.upperBound,
                value: Value.repeating(base.piece.value, until: limit),
                priority: 1)
            return Candidate(piece: piece, hint: .none)
        }

        // Ends in text order after each repeating day, until the gap holds a
        // word no end allows.
        let bounded = repeating.flatMap { base -> [Candidate] in
            var found: [Candidate] = []
            for end in near.starting(from: base.piece.range.upperBound) {
                guard let until = saysUntil(after: base, before: end.piece.range.lowerBound) else { break }
                if case .lasting(.days(0), let length) = end.piece.value, !until {
                    found.append(joined(base, end.piece.range, .length(length)))
                    continue
                }
                // "toda terça, 3 vezes ao dia" repeats three times each day.
                if case .timesPer(let count, let unit) = end.piece.value, !until {
                    let range = base.piece.range.lowerBound..<end.piece.range.upperBound
                    let piece = Piece(
                        range: range, value: Value.rated(base.piece.value, count, per: unit), priority: 1)
                    found.append(Candidate(piece: piece, hint: .none))
                    continue
                }
                guard end.piece.value.recurrence == nil else { continue }
                // "até" once, in the gap or opening the day: "até dezembro".
                let opens = source.words(after: end.piece.range.lowerBound, count: 1).first == "ate"
                guard until != opens else { continue }
                found.append(joined(base, end.piece.range, .day(end.piece.value)))
            }
            return found
        }
        let counted = source.matches(of: occurrences, whenAny: ["vezes"]).flatMap { match -> [Candidate] in
            guard let count = SpokenNumber.value(match.output.1), count > 0 else { return [] }
            var found: [Candidate] = []
            for base in near.ending(by: match.range.lowerBound) {
                guard let until = saysUntil(after: base, before: match.range.lowerBound) else { break }
                guard base.piece.value.recurrence != nil, !until else { continue }
                found.append(joined(base, match.range, .count(count)))
            }
            return found
        }
        return bounded + counted
    }

    /// A weekday followed by its date: "sexta, dia 25", "segunda-feira, 5/10".
    /// The date decides, and the date is the hint the weekday needs.
    private static func weekdaysWithDates(of near: Neighbours, in source: TextSource) -> [Candidate] {
        near.byStart.flatMap { weekday -> [Candidate] in
            guard case .weekday = weekday.piece.value else { return [] }
            var found: [Candidate] = []
            for date in near.starting(from: weekday.piece.range.upperBound) {
                guard source.hasNoWord(in: weekday.piece.range.upperBound..<date.piece.range.lowerBound)
                else {
                    break
                }
                guard date.piece.value.isDate else { continue }
                let range = weekday.piece.range.lowerBound..<date.piece.range.upperBound
                // "sáb - 3/10" is that date, not a range from Saturday to it.
                let piece = Piece(range: range, value: date.piece.value, priority: 1)
                found.append(Candidate(piece: piece, hint: date.hint == .date ? .date : .none))
            }
            return found
        }
    }

    /// Whether the position falls inside one of the times, which are in
    /// text order: the one that starts last at or before it.
    static func isInsideTime(_ index: String.Index, _ times: [TimeRules.Expression], in source: TextSource)
        -> Bool
    {
        let next = firstIndex(in: times, from: source.normalized.index(after: index)) { $0.range.lowerBound }
        return next > 0 && times[next - 1].range.contains(index)
    }

    /// Every few weeks, on these weekdays: "toda semana na quarta", "reunião
    /// quinzenal às quintas", "às terças, de 2 em 2 semanas".
    private static func weeklyEvery(of near: Neighbours, in source: TextSource) -> [Candidate] {
        func weeks(_ value: Value) -> Int? {
            guard case .interval(let components) = value, let weeks = components.weekOfYear,
                components.day == nil, components.month == nil
            else { return nil }
            return weeks
        }
        func days(_ value: Value) -> [Int]? {
            switch value {
            case .weekday(let day, nil): [day]
            case .weekly(let days, 1) where !days.isEmpty: days
            default: nil
            }
        }
        return near.byStart.flatMap { first -> [Candidate] in
            near.starting(from: first.piece.range.upperBound).prefix { second in
                source.onlyConnectors(between: first.piece.range, and: second.piece.range)
            }.compactMap { second in
                let pair =
                    weeks(first.piece.value).flatMap { every in days(second.piece.value).map { ($0, every) } }
                    ?? weeks(second.piece.value).flatMap { every in
                        days(first.piece.value).map { ($0, every) }
                    }
                guard let (weekdays, every) = pair else { return nil }
                let range = first.piece.range.lowerBound..<second.piece.range.upperBound
                return Candidate(
                    piece: Piece(range: range, value: .weekly(weekdays, every: every), priority: 1),
                    hint: .none)
            }
        }
    }

    /// A date followed by its weekday: "15/10, quinta", "28/9 (seg)",
    /// "02/10 sexta-feira". The date decides, as when the weekday comes first.
    private static func datesWithWeekdays(of near: Neighbours, in source: TextSource) -> [Candidate] {
        near.byStart.flatMap { date -> [Candidate] in
            guard date.piece.value.isDate else { return [] }
            var found: [Candidate] = []
            for weekday in near.starting(from: date.piece.range.upperBound) {
                guard source.hasNoWord(in: date.piece.range.upperBound..<weekday.piece.range.lowerBound)
                else {
                    break
                }
                guard case .weekday = weekday.piece.value else { continue }
                let range = date.piece.range.lowerBound..<weekday.piece.range.upperBound
                let piece = Piece(range: range, value: date.piece.value, priority: 1)
                found.append(Candidate(piece: piece, hint: date.hint == .date ? .date : .none))
            }
            return found
        }
    }

    /// The candidates in text order, so a joining step looks only at the
    /// ones next to where it stands instead of at every pair.
    struct Neighbours {
        let byStart: [Candidate]
        let byEnd: [Candidate]

        init(_ candidates: [Candidate]) {
            byStart = candidates.sorted { $0.piece.range.lowerBound < $1.piece.range.lowerBound }
            byEnd = candidates.sorted { $0.piece.range.upperBound < $1.piece.range.upperBound }
        }

        /// The candidates that start at or after the position, nearest first.
        func starting(from index: String.Index) -> ArraySlice<Candidate> {
            byStart[firstIndex(in: byStart, from: index) { $0.piece.range.lowerBound }...]
        }

        /// The candidates that end at or before the position, nearest first.
        func ending(by index: String.Index) -> ReversedCollection<ArraySlice<Candidate>> {
            var end = firstIndex(in: byEnd, from: index) { $0.piece.range.upperBound }
            while end < byEnd.count, byEnd[end].piece.range.upperBound == index { end += 1 }
            return byEnd[..<end].reversed()
        }
    }

    /// The first element whose key is at or after the position, in an array
    /// sorted by that key; the count when there is none.
    static func firstIndex<Element>(
        in sorted: [Element], from index: String.Index, key: (Element) -> String.Index
    ) -> Int {
        var low = 0
        var high = sorted.count
        while low < high {
            let middle = (low + high) / 2
            if key(sorted[middle]) < index { low = middle + 1 } else { high = middle }
        }
        return low
    }

    static func candidates(in source: TextSource) -> [Candidate] {
        var found: [Candidate] = []

        func add(_ range: Range<String.Index>, _ value: Value, hint: Candidate.Hint = .none) {
            found.append(Candidate(piece: Piece(range: range, value: value), hint: hint))
        }

        for match in source.matches(of: relativeDay, whenAny: relativeDayWords) {
            guard let days = relativeDays[String(match.output.1)] else { continue }
            add(match.range, .days(days))
        }

        for match in source.matches(of: inAmount, whenAny: amountWords) {
            guard let count = SpokenNumber.value(match.output.2), count > 0 else { continue }
            let (unit, half) = (match.output.3, match.output.4 != nil)
            // "1 mês e meio" is a month and fifteen days, "1 ano e meio" a year
            // and six months, "uma semana e meia" a week and three days.
            let extra: DateComponents? =
                !half
                ? nil
                : unit.hasPrefix("mes")
                    ? DateComponents(day: 15)
                    : unit.hasPrefix("ano")
                        ? DateComponents(month: 6)
                        : unit.hasPrefix("semana") ? DateComponents(day: 3) : nil
            guard !half || extra != nil else { continue }
            add(
                match.range,
                extra.map { .shifted(amount(count, unit: unit), by: $0) } ?? amount(count, unit: unit))
        }

        for match in source.matches(of: prescription, whenContains: "/") {
            guard let count = Int(match.output.1), count > 0, Int(match.output.2) == count else { continue }
            add(match.range, .interval(DateComponents(hour: count)))
        }

        for match in source.matches(of: agoAmount, whenAny: agoWords) {
            guard let count = SpokenNumber.value(match.output.1) else { continue }
            add(match.range, amount(-count, unit: match.output.2))
        }

        for match in source.matches(of: amountAgo, whenAny: backWords) {
            guard let count = SpokenNumber.value(match.output.1) else { continue }
            add(match.range, amount(-count, unit: match.output.2))
        }

        for match in source.matches(of: lastWeekday, whenAny: lastWords) {
            guard let name = match.output.1 ?? match.output.2, let day = weekdays[String(name)] else {
                continue
            }
            // "sábado retrasado" is the one before last.
            add(match.range, .lastWeekday(day, weeks: match.output.3?.hasPrefix("retrasad") == true ? 2 : 1))
        }

        for match in source.matches(of: everyDay, whenAny: everyDayWords) {
            add(match.range, .daily)
        }

        for match in source.matches(of: everyInterval, whenAny: intervalWords) {
            guard let count = SpokenNumber.value(match.output.1), count > 0 else { continue }
            add(match.range, .interval(components(count, unit: match.output.2)))
        }

        for match in source.matches(of: fromToInterval, whenAny: fromToWords) {
            // "de 2 em 3 semanas" is not an interval.
            guard let count = SpokenNumber.value(match.output.1), count > 0,
                SpokenNumber.value(match.output.2) == count
            else { continue }
            add(match.range, .interval(components(count, unit: match.output.3)))
        }

        for match in source.matches(of: everyUnit, whenAny: everyUnitWords) {
            // "quinzenal" is every other week.
            if match.output.contains("quinzena") {
                add(match.range, .interval(DateComponents(weekOfYear: 2)))
                continue
            }
            let unit =
                if match.output.contains("hora") { "hora" } else if match.output.contains("semana") {
                    "semana"
                } else { "mes" }
            add(match.range, .interval(components(1, unit: unit)))
        }

        for match in source.matches(of: monthlyDay, whenAny: monthlyWords) {
            guard let day = dayNumber(match.output.1), (1...31).contains(day) else { continue }
            add(match.range, .monthly([day]))
        }

        for match in source.matches(of: everyMonth, whenAny: monthlyWords) {
            // "todo dia 30 minutos" counts minutes every day. "todo dia 15 e
            // 30" is both.
            let more =
                match.output.2.map { $0.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) } } ?? []
            guard let day = dayNumber(match.output.1), (1...31).contains(day),
                more.allSatisfy((1...31).contains),
                source.endsPhrase(at: match.range.upperBound)
            else { continue }
            add(match.range, .monthly([day] + more))
        }

        for match in source.matches(of: everyMonthEnd, whenAny: monthlyWords) {
            add(match.range, .monthly([match.output.1 == nil ? -1 : 1]))
        }

        for match in source.matches(of: everyBusinessDay, whenAny: businessWords) {
            add(match.range, .weekly([2, 3, 4, 5, 6], every: 1))
        }

        for match in source.matches(of: everyWeekend, whenAny: ["fim", "fins", "final", "finais", "fds"]) {
            add(match.range, .weekly([7, 1], every: 1))
        }

        for match in source.matches(of: everyWeekdayRange, whenAny: everyWeekdayWords) {
            guard let first = weekdays[String(match.output.1)], let last = weekdays[String(match.output.2)]
            else {
                continue
            }
            // Monday to Friday, or across the weekend: "toda sexta a segunda".
            let count = (last - first + 7) % 7
            add(match.range, .weekly((0...count).map { (first - 1 + $0) % 7 + 1 }, every: 1))
        }

        // "toda noite": every day, at the time of that part of the day, which
        // the time rules read from the same words.
        for match in source.matches(of: everyPartOfDay, whenAny: everyWeekdayWords) {
            add(match.range, .daily, hint: .time)
        }

        for match in source.matches(of: timesPer, whenAny: timesWords, orDigit: true) {
            guard let count = SpokenNumber.value(match.output.1), count > 0 else { continue }
            add(match.range, .timesPer(count, components(1, unit: match.output.2)))
        }

        for match in source.matches(of: everyOther, whenAny: everyOtherWords)
        where match.output.1 == match.output.2 {
            add(match.range, .interval(components(2, unit: match.output.1)))
        }

        for match in source.matches(of: nthWeekday, whenAny: ["mes"]) {
            guard let ordinal = ordinals[String(match.output.1)],
                let weekday = weekdays[String(match.output.2)]
            else { continue }
            add(match.range, .nthWeekday(ordinal, weekday: weekday))
        }

        for match in source.matches(of: everyYear, whenAny: everyYearWords) {
            add(match.range, .yearly(month: match.output.1.flatMap { months[String($0)] }))
        }

        for match in source.matches(of: everyDate, whenAny: everyDateWords) {
            guard let day = dayNumber(match.output.1), let month = months[String(match.output.2)] else {
                continue
            }
            add(match.range, .yearlyOn(day: day, month: month))
        }

        for match in source.matches(of: everyWeekday, whenAny: everyWeekdayWords) {
            // The singular goes with "toda" ("toda segunda"), the plural with
            // "todas as", "às" or "nas" ("às segundas e quartas").
            let plural = match.output.1 != "toda" && match.output.1 != "todo"
            let days = match.output.2.split(whereSeparator: { $0 == " " || $0 == "," }).filter {
                $0 != "e" && !$0.hasPrefix("feira")
            }
            .map { word in
                let name = word.split(separator: "-").first.map(String.init) ?? ""
                return name.hasSuffix("s") == plural
                    ? weekdays[plural ? String(name.dropLast()) : name] : nil
            }
            // "nas quartas de final", "as segundas intenções".
            guard !days.isEmpty, !days.contains(nil), !isOrdinal(match.range, in: source) else { continue }
            add(match.range, .weekly(days.compactMap { $0 }, every: 1))
        }

        // "segundas e quartas às 19h": plural weekdays with no preposition
        // still repeat, where a phrase can end or a time follows.
        for match in source.matches(of: pluralWeekdays, whenAny: pluralWeekdayWords) {
            let days = match.output.split(whereSeparator: { $0 == " " || $0 == "," }).filter { $0 != "e" }.map
            {
                weekdays[String(($0.split(separator: "-").first ?? $0).dropLast())]
            }
            guard !days.isEmpty, !days.contains(nil), !isOrdinal(match.range, in: source) else { continue }
            add(
                match.range, .weekly(days.compactMap { $0 }, every: 1),
                hint: source.endsPhrase(at: match.range.upperBound) ? .none : .time)
        }

        for match in source.matches(of: weekday, whenAny: weekdayWords) {
            let (prefix, name, feira, next) = (
                match.output.1, String(match.output.2), match.output.3, match.output.4
            )
            // An ordinal before its noun: "na segunda fase", "na quinta posição".
            guard let day = weekdays[name], feira != nil || next != nil || !isOrdinal(match.range, in: source)
            else { continue }
            // "sexta que vem" is next week's; "sexta dessa semana" is this one.
            let week: Int? =
                next.map(chat).map {
                    $0.contains("semana que vem") || $0.contains("proxima semana")
                        ? 1 : $0.contains("dessa semana") || $0.contains("desta semana") ? 0 : nil
                } ?? nil
            let unambiguous =
                weekdaysAlone.contains(name) || prefix != nil || feira != nil || next != nil
                || standsAlone(name, match.range, in: source)
            add(match.range, .weekday(day, week: week), hint: unambiguous ? .none : .time)
        }

        // A bare number needs a digit in the text, and must not count
        // something: "sexta 25 pessoas".
        for match in source.hasDigit ? source.matches(of: weekdayAndDay, whenAny: weekdayWords) : [] {
            guard let weekday = weekdays[String(match.output.1)], let day = Int(match.output.2),
                source.endsPhrase(at: match.range.upperBound)
            else { continue }
            add(match.range, .weekdayAndDay(weekday, day: day), hint: .date)
        }

        // "ter" is the verb "to have"; followed by its full stop or a comma it
        // is Tuesday, as calendars write it before a date: "ter., 29 de set.".
        // Alone it only anchors that date.
        for match in source.matches(of: tuesdayAbbreviation, whenAny: ["ter"])
        where ",.".contains(
            source.originalText(
                match.range.upperBound..<source.normalized.index(after: match.range.upperBound)))
        {
            add(match.range, .weekday(3, week: nil), hint: .anchor)
        }

        for match in source.matches(of: numericDate, whenContains: "/") {
            guard let day = Int(match.output.1), let month = Int(match.output.2),
                match.output.3 != nil || !isFraction(match.range, in: source)
            else { continue }
            add(match.range, .date(day: day, month: month, year: match.output.3.flatMap { year(String($0)) }))
        }

        for match in source.matches(of: separatedDate, whenContainsAny: ["-", "."]) {
            let (_, dayText, _, monthText, yearText) = match.output
            guard let day = Int(dayText), let month = Int(monthText) else { continue }
            add(match.range, .date(day: day, month: month, year: year(String(yearText))))
        }

        for match in source.matches(of: slashMonth, whenContains: "/") {
            guard let day = Int(match.output.1), let month = months[String(match.output.2)] else { continue }
            add(match.range, .date(day: day, month: month, year: match.output.3.flatMap { year(String($0)) }))
        }

        for match in source.matches(of: monthYear, whenContains: "/") {
            let (_, name, shortYear, number, fullYear) = match.output
            if let name, let shortYear, let month = months[String(name)] {
                add(match.range, .month(month, year: year(String(shortYear))))
            } else if let number, let fullYear, let month = Int(number), (1...12).contains(month) {
                add(match.range, .month(month, year: Int(fullYear)))
            }
        }

        for match in source.matches(of: isoDateTime, whenContains: "-") {
            let (_, year, month, day, hour, minute, zone) = match.output
            guard let year = Int(year), let month = Int(month), let day = Int(day), let hour = Int(hour),
                let minute = Int(minute), (0...23).contains(hour), (0...59).contains(minute),
                isValidDate(day: day, month: month, year: year)
            else { continue }
            let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
            add(match.range, .dateTime(components, offset: zone.flatMap(offset)))
        }

        for match in source.matches(of: isoDate, whenContains: "-") {
            guard let year = Int(match.output.1), let month = Int(match.output.2),
                let day = Int(match.output.3)
            else { continue }
            add(match.range, .date(day: day, month: month, year: year))
        }

        for match in source.matches(of: monthName, whenAny: monthWords) {
            let (_, dayText, of, monthText, yearText) = match.output
            // A day in words needs "de": "um mar de rosas" is not a date. A
            // street named after a date is a place: "Rua 25 de Março".
            guard Int(dayText) != nil || of != nil,
                let day = dayNumber(dayText), let month = months[String(monthText)],
                !(source.word(before: match.range.lowerBound).map(placeWords.contains) ?? false)
            else { continue }
            let year = yearText.flatMap { Int($0) }.flatMap { (1900...2199).contains($0) ? $0 : nil }
            // A number that is not a year ends the date: "Rua 25 de Março, 1000".
            let range =
                year == nil && yearText != nil ? match.range.lowerBound..<monthText.endIndex : match.range
            add(range, .date(day: day, month: month, year: year))
        }

        for match in source.matches(of: dayRangeInMonth, whenAny: monthWords) {
            let (_, opening, firstText, closing, lastText, monthText, yearText) = match.output
            // "de 3 e 5 de maio" is two days, not a range.
            guard (opening == "entre") == (closing == "e"),
                let first = dayNumber(firstText), let last = dayNumber(lastText),
                let month = months[String(monthText)]
            else { continue }
            let year = yearText.flatMap { Int($0) }
            add(
                match.range,
                .range(
                    .date(day: first, month: month, year: year), .date(day: last, month: month, year: year)))
        }

        for match in source.matches(of: dayNumberRange, whenAny: ["dia", "dias"]) {
            let (_, opening, firstText, closing, lastText) = match.output
            guard opening.hasPrefix("entre") == (closing == "e"), let first = dayNumber(firstText),
                let last = dayNumber(lastText), first < last
            else { continue }
            add(match.range, .range(.dayOfMonth(first), .dayOfMonth(last)))
        }

        for match in source.matches(of: dayRangeToDate, whenContains: "/") {
            let (_, opening, firstText, closing, lastText, monthText, yearText) = match.output
            guard (opening == "entre") == (closing == "e"), let first = Int(firstText),
                let last = Int(lastText),
                let month = Int(monthText), first < last
            else { continue }
            let year = yearText.flatMap { Self.year(String($0)) }
            add(
                match.range,
                .range(
                    .date(day: first, month: month, year: year), .date(day: last, month: month, year: year)))
        }

        for match in source.matches(of: hyphenDayRange, whenAny: monthWords) {
            let (_, firstText, lastText, monthText, yearText) = match.output
            guard let first = Int(firstText), let last = Int(lastText), first < last,
                let month = months[String(monthText)]
            else { continue }
            let year = yearText.flatMap { Int($0) }
            add(
                match.range,
                .range(
                    .date(day: first, month: month, year: year), .date(day: last, month: month, year: year)))
        }

        for match in source.matches(of: monthRange, whenAny: monthWords) {
            let (_, opening, firstText, closing, lastText, yearText) = match.output
            guard (opening == "entre") == (closing == "e"), let first = months[String(firstText)],
                let last = months[String(lastText)]
            else { continue }
            let year = yearText.flatMap { Int($0) }
            // "de março a maio de 2027": the year is both ends' unless the
            // range crosses into it.
            add(
                match.range,
                .range(
                    .month(first, year: first <= last ? year : year.map { $0 - 1 }), .month(last, year: year))
            )
        }

        for match in source.matches(of: dayOfMonth, whenAny: dayWords) {
            guard let day = dayNumber(match.output.1) else { continue }
            add(match.range, .dayOfMonth(day))
        }

        for match in source.matches(of: holidayName, whenAny: holidayWords) {
            let (_, preposition, name, year) = match.output
            guard let entry = holidays[String(name)] else { continue }
            // "fantasia de carnaval" is not a date, but "dois dias antes do
            // carnaval" and "natal de 2027" are: without its preposition or a
            // year the name only anchors.
            add(
                match.range, .holiday(entry.holiday, year: year.flatMap { Int($0) }),
                hint: preposition == nil && year == nil && entry.needsPreposition ? .anchor : .none)
        }

        for match in source.matches(of: lasting, whenAny: lastingWords) {
            guard let count = SpokenNumber.value(match.output.1), count > 0 else { continue }
            add(match.range, .lasting(.days(0), for: components(count, unit: match.output.2)))
        }

        for match in source.matches(of: businessDays, whenAny: businessWords) {
            guard let count = SpokenNumber.value(match.output.1) else { continue }
            add(match.range, .businessDays(count))
        }

        for match in source.matches(of: namedBusinessDay, whenAny: businessWords) {
            add(match.range, .businessDays(1))
        }

        for match in source.matches(of: nthBusinessDay, whenAny: businessWords) {
            let (_, ordinal, next, _, named, year) = match.output
            let place = ordinal.first?.isNumber == true ? Int(ordinal.dropLast()) : ordinals[String(ordinal)]
            guard let place, place != 0 else { continue }
            add(match.range, inMonth(.nthBusinessDayOfMonth(place), next: next, named: named, year: year))
        }

        for match in source.matches(of: nthWeekdayInMonth, whenAny: monthWords.union(["mes"])) {
            let (_, ordinal, name, next, _, named, year) = match.output
            guard let place = ordinals[String(ordinal)], let weekday = weekdays[String(name)] else {
                continue
            }
            add(
                match.range,
                inMonth(.nthWeekdayOfMonth(place, weekday: weekday), next: next, named: named, year: year))
        }

        for match in source.matches(of: weekOfMonth, whenAny: ["semana"]) {
            let (_, ordinal, next, _, named, year) = match.output
            guard let place = ordinals[String(ordinal)], (-1...4).contains(place) else { continue }
            add(match.range, inMonth(.weekOfMonth(place), next: next, named: named, year: year))
        }

        for match in source.matches(of: partOfMonth, whenAny: monthWords) {
            let (_, part, named, year) = match.output
            guard let month = months[String(named)] else { continue }
            let inner: Value =
                switch part {
                case "inicio", "comeco": .dayOfMonth(1)
                case "fim", "final": .endOfMonth(months: 0)
                default: .dayOfMonth(15)
                }
            add(match.range, .within(inner, .month(month, year: year.flatMap { Int($0) })))
        }

        for match in source.matches(of: wholeMonth, whenAny: monthWords) {
            let (_, preposition, withPreposition, comingMonth, withYear, year) = match.output
            guard let name = withPreposition ?? comingMonth ?? withYear, let month = months[String(name)]
            else { continue }
            // "marco" without its cedilla is also a name and a noun: "para
            // Marco", "no Marco Zero". It is March after "em" or before a year.
            if name == "marco", !source.originalText(match.range).contains(where: { "çÇ".contains($0) }),
                withPreposition != nil, !["em", "no mes de"].contains(preposition ?? ""), year == nil
            {
                continue
            }
            add(match.range, .month(month, year: year.flatMap { Int($0) }))
        }

        for match in source.matches(of: yearPart, whenAny: yearPartWords) {
            let (_, ordinal, unit, year) = match.output
            guard let part = ordinals[String(ordinal)], let parts = yearParts[String(unit)], part <= parts
            else { continue }
            add(match.range, .yearPart(part, of: parts, year: year.flatMap { Int($0) }))
        }

        for match in source.matches(of: yearPartFromNow, whenAny: yearPartWords) {
            let (_, this, next, coming) = match.output
            guard let unit = this ?? next ?? coming, let parts = yearParts[String(unit)] else { continue }
            add(match.range, .yearPartFromNow(this == nil ? 1 : 0, of: parts))
        }

        for match in source.matches(of: halfMonth, whenAny: halfMonthWords) {
            let (_, ordinal, month, year) = match.output
            guard let half = ordinals[String(ordinal)] else { continue }
            add(
                match.range,
                .halfMonth(half, month: month.flatMap { months[String($0)] }, year: year.flatMap { Int($0) }))
        }

        for match in source.matches(of: namedPeriod, whenAny: periodWords) {
            let value: Value =
                switch chat(match.output.1) {
                case "fim de semana que vem", "final de semana que vem", "proximo fim de semana",
                    "proximo final de semana":
                    .weekend(weeks: 1)
                case "fim de semana passado", "final de semana passado", "ultimo fim de semana",
                    "ultimo final de semana":
                    .weekend(weeks: -1)
                case "fim do mes que vem", "final do mes que vem": .endOfMonth(months: 1)
                case "esta semana", "essa semana", "nesta semana", "nessa semana": .thisWeek
                case "semana que vem", "proxima semana", "prox semana", "essa semana que vem",
                    "esta semana que vem":
                    .nextWeek
                case "este mes", "esse mes", "neste mes", "nesse mes": .thisMonth
                case "mes que vem", "proximo mes", "prox mes": .nextMonth
                case "comeco do mes que vem", "inicio do mes que vem", "comeco do proximo mes",
                    "inicio do proximo mes":
                    .startOfNextMonth
                case "fim do mes", "final do mes", "ultimo dia do mes": .endOfMonth(months: 0)
                case "inicio do mes", "comeco do mes", "primeiro dia do mes": .dayOfMonth(1)
                case "meio do mes", "metade do mes": .dayOfMonth(15)
                case "inicio do ano", "comeco do ano": .startOfYear
                case "meio do ano", "metade do ano": .middleOfYear
                case "fim do ano", "final do ano": .endOfYear
                case "durante a semana": .workWeek
                case "inicio da semana que vem", "comeco da semana que vem": .within(.startOfWeek, .nextWeek)
                case "meio da semana que vem": .within(.middleOfWeek, .nextWeek)
                case "fim da semana que vem", "final da semana que vem": .within(.endOfWeek, .nextWeek)
                case "inicio do ano que vem", "comeco do ano que vem": .within(.startOfYear, .nextYear)
                case "meio do ano que vem": .within(.middleOfYear, .nextYear)
                case "fim do ano que vem", "final do ano que vem": .within(.endOfYear, .nextYear)
                case "comeco da semana", "inicio da semana": .startOfWeek
                case "meio da semana", "metade da semana": .middleOfWeek
                case "fim da semana", "final da semana": .endOfWeek
                case "ano que vem", "proximo ano", "prox ano": .nextYear
                case "semana passada": .lastWeek(1)
                case "semana retrasada": .lastWeek(2)
                case "mes passado": .lastMonth(1)
                case "mes retrasado": .lastMonth(2)
                case "ano passado": .lastYear(1)
                case "ano retrasado": .lastYear(2)
                default: .weekend(weeks: 0)
                }
            add(match.range, value)
        }

        return found
    }

    // Computed, not stored: `Regex` is not `Sendable`, and a nonisolated static
    // constant has to be. `RegexCache` keeps each one built per thread. The
    // literal is still checked at compile time. Simple word boundaries: the
    // text arrives without accents or punctuation.

}
