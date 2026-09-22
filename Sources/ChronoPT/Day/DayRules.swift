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
        }
    }

    /// The days mentioned in the text, without overlap, in text order.
    static func expressions(in source: TextSource, times: [TimeRules.Expression]) -> [Piece<Value>] {
        let found = candidates(in: source)
        let candidates =
            (found + ranges(of: found, in: source) + weekdaysWithDates(of: found, in: source)
            + offsets(of: found, in: source))
            .filter { candidate in
                switch candidate.hint {
                case .none: return true
                case .anchor: return false
                case .time: break
                }
                return times.contains { time in
                    guard !time.isFromNow else { return false }
                    guard source.onlyConnectors(between: candidate.piece.range, and: time.range) else {
                        return false
                    }
                    // A time before the day only counts with "de": "às 10 de
                    // quinta" is Thursday, but "às 10 segunda via" is not Monday.
                    return time.range.lowerBound >= candidate.piece.range.upperBound
                        || source.word(before: candidate.piece.range.lowerBound) == "de"
                }
            }
        return Piece.nonOverlapping(candidates.map(\.piece), in: source)
    }

    /// Two days joined as a range: "de segunda a sexta", "do dia 10 ao dia
    /// 15", "de hoje até sexta", "segunda a sexta", "seg-sex". The range is the
    /// hint a weekday needs. With no opening word, the first day has to start
    /// right at its number or name.
    private static func ranges(of candidates: [Candidate], in source: TextSource) -> [Candidate] {
        candidates.flatMap { first -> [Candidate] in
            // Hoisted: both only depend on the first candidate, and each one
            // used to scan the rest of the text for every pair.
            let firstWord = source.words(after: first.piece.range.lowerBound, count: 1).first ?? ""
            let bareStart = source.startsWithNumber(first.piece.range) || weekdays[firstWord] != nil
            return candidates.compactMap { second in
                guard first.piece.range.upperBound <= second.piece.range.lowerBound else { return nil }
                guard
                    let start = source.rangeStart(
                        from: first.piece.range, to: second.piece.range, bareStart: bareStart)
                else {
                    return nil
                }
                // A day of the month takes the month of the end: "do dia 10 ao
                // dia 15 de novembro".
                var from = first.piece.value
                if case .dayOfMonth(let day) = from, case let .date(last, month, year) = second.piece.value,
                    day <= last
                {
                    from = .date(day: day, month: month, year: year)
                }
                let piece = Piece(
                    range: start..<second.piece.range.upperBound, value: Value.range(from, second.piece.value)
                )
                return Candidate(piece: piece, hint: .none)
            }
        }
    }

    /// A day counted from another: "dois dias antes do natal", "uma semana
    /// depois do dia 10", "véspera do ano novo". The day it counts from sits
    /// right after the lead, and is the hint a holiday name needs.
    private static func offsets(of candidates: [Candidate], in source: TextSource) -> [Candidate] {
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
            return candidates.compactMap { base in
                guard base.piece.range.lowerBound >= lead.range.upperBound,
                    source.hasNoWord(in: lead.range.upperBound..<base.piece.range.lowerBound)
                else { return nil }
                let range = lead.range.lowerBound..<base.piece.range.upperBound
                let piece = Piece(
                    range: range, value: Value.shifted(base.piece.value, by: shift), priority: 1)
                return Candidate(piece: piece, hint: .none)
            }
        }
    }

    /// A weekday followed by its date: "sexta, dia 25", "segunda-feira, 5/10".
    /// The date decides, and the date is the hint the weekday needs.
    private static func weekdaysWithDates(of candidates: [Candidate], in source: TextSource) -> [Candidate] {
        candidates.flatMap { weekday in
            candidates.compactMap { date in
                guard case .weekday = weekday.piece.value,
                    date.piece.value.isDate,
                    weekday.piece.range.upperBound <= date.piece.range.lowerBound,
                    source.hasNoWord(in: weekday.piece.range.upperBound..<date.piece.range.lowerBound)
                else { return nil }
                let range = weekday.piece.range.lowerBound..<date.piece.range.upperBound
                // "sáb - 3/10" is that date, not a range from Saturday to it.
                let piece = Piece(range: range, value: date.piece.value, priority: 1)
                return Candidate(piece: piece, hint: .none)
            }
        }
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
            guard let count = SpokenNumber.value(match.output.2) else { continue }
            add(match.range, amount(count, unit: match.output.3))
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
            add(match.range, .lastWeekday(day))
        }

        for match in source.matches(of: everyDay, whenAny: everyDayWords) {
            add(match.range, .daily)
        }

        for match in source.matches(of: everyInterval, whenAny: intervalWords) {
            guard let count = SpokenNumber.value(match.output.1) else { continue }
            add(match.range, .interval(components(count, unit: match.output.2)))
        }

        for match in source.matches(of: fromToInterval, whenAny: fromToWords) {
            // "de 2 em 3 semanas" is not an interval.
            guard let count = SpokenNumber.value(match.output.1), SpokenNumber.value(match.output.2) == count
            else { continue }
            add(match.range, .interval(components(count, unit: match.output.3)))
        }

        for match in source.matches(of: everyUnit, whenAny: everyUnitWords) {
            let unit =
                if match.output.contains("hora") { "hora" } else if match.output.contains("semana") {
                    "semana"
                } else { "mes" }
            add(match.range, .interval(components(1, unit: unit)))
        }

        for match in source.matches(of: monthlyDay, whenAny: monthlyWords) {
            guard let day = dayNumber(match.output.1), (1...31).contains(day) else { continue }
            add(match.range, .monthly(day))
        }

        for match in source.matches(of: everyMonth, whenAny: monthlyWords) {
            guard let day = dayNumber(match.output.1), (1...31).contains(day) else { continue }
            add(match.range, .monthly(day))
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
            guard !days.isEmpty, !days.contains(nil) else { continue }
            add(match.range, .weekly(days.compactMap { $0 }))
        }

        for match in source.matches(of: weekday, whenAny: weekdayWords) {
            let (prefix, name, feira, next) = (
                match.output.1, String(match.output.2), match.output.3, match.output.4
            )
            guard let day = weekdays[name] else { continue }
            // "sexta que vem" is next week's; "sexta dessa semana" is this one.
            let nextWeek =
                next.map { $0.contains("semana que vem") || $0.contains("proxima semana") } ?? false
            let unambiguous = weekdaysAlone.contains(name) || prefix != nil || feira != nil || next != nil
            add(match.range, .weekday(day, nextWeek: nextWeek), hint: unambiguous ? .none : .time)
        }

        for match in source.matches(of: numericDate, whenContains: "/") {
            guard let day = Int(match.output.1), let month = Int(match.output.2) else { continue }
            add(match.range, .date(day: day, month: month, year: match.output.3.flatMap { year(String($0)) }))
        }

        for match in source.matches(of: isoDate, whenContains: "-") {
            guard let year = Int(match.output.1), let month = Int(match.output.2),
                let day = Int(match.output.3)
            else { continue }
            add(match.range, .date(day: day, month: month, year: year))
        }

        for match in source.matches(of: monthName, whenAny: monthWords) {
            let (_, dayText, of, monthText, yearText) = match.output
            // A day in words needs "de": "um mar de rosas" is not a date.
            guard Int(dayText) != nil || of != nil,
                let day = dayNumber(dayText), let month = months[String(monthText)]
            else { continue }
            add(match.range, .date(day: day, month: month, year: yearText.flatMap { Int($0) }))
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

        for match in source.matches(of: dayOfMonth, whenAny: dayWords) {
            guard let day = dayNumber(match.output.1) else { continue }
            add(match.range, .dayOfMonth(day))
        }

        for match in source.matches(of: holidayName, whenAny: holidayWords) {
            let (_, preposition, name) = match.output
            guard let entry = holidays[String(name)] else { continue }
            // "fantasia de carnaval" is not a date, but "dois dias antes do
            // carnaval" is: without its preposition the name only anchors.
            add(
                match.range, .holiday(entry.holiday),
                hint: preposition == nil && entry.needsPreposition ? .anchor : .none)
        }

        for match in source.matches(of: businessDays, whenAny: businessWords) {
            guard let count = SpokenNumber.value(match.output.1) else { continue }
            add(match.range, .businessDays(count))
        }

        for match in source.matches(of: namedBusinessDay, whenAny: businessWords) {
            let value: Value =
                switch match.output.1 {
                case "primeiro dia util": .firstBusinessDayOfMonth
                case "ultimo dia util": .lastBusinessDayOfMonth
                default: .businessDays(1)
                }
            add(match.range, value)
        }

        for match in source.matches(of: wholeMonth, whenAny: monthWords) {
            let (_, withPreposition, comingMonth, withYear, year) = match.output
            guard let name = withPreposition ?? comingMonth ?? withYear, let month = months[String(name)]
            else { continue }
            add(match.range, .month(month, year: year.flatMap { Int($0) }))
        }

        for match in source.matches(of: namedPeriod, whenAny: periodWords) {
            let value: Value =
                switch match.output.1 {
                case "fim de semana que vem", "final de semana que vem", "proximo fim de semana",
                    "proximo final de semana":
                    .weekend(weeks: 1)
                case "fim de semana passado", "final de semana passado": .weekend(weeks: -1)
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
                case "comeco da semana", "inicio da semana": .startOfWeek
                case "meio da semana", "metade da semana": .middleOfWeek
                case "fim da semana", "final da semana": .endOfWeek
                case "ano que vem", "proximo ano", "prox ano": .nextYear
                case "semana passada": .lastWeek
                case "mes passado": .lastMonth
                case "ano passado": .lastYear
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
