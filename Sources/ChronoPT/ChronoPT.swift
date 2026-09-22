import Foundation

/// Natural-language dates and times in Brazilian Portuguese.
///
/// ```swift
/// ChronoPT.interpret("comprar pão amanhã no almoço")   // tomorrow, 12:00
/// ChronoPT.parse("dentista sexta às 14h e reunião dia 30")  // two dates
/// ```
///
/// A small grammar in the style of chrono (github.com/wanasit/chrono): rules
/// find day pieces ("amanhã", "sexta que vem", "dia 30") and time pieces
/// ("às 9", "no almoço", "de madrugada"), then a day and a time are joined.
/// A new case is a new rule in `DayRules` or a new row in the `TimeRules`
/// table, without touching the rest.
///
/// Everything is computed from `reference` and `calendar`: the same text with
/// the same reference always gives the same answer, on any OS version.
public enum ChronoPT {
    /// Every date and time expression in the text, in the order they appear.
    ///
    /// A day and a time next to each other ("amanhã às 9", "sexta à noite")
    /// come out as one expression. A time with no day falls on today, or on
    /// tomorrow if that time has already passed.
    public static func parse(
        _ text: String,
        reference: Date = .now,
        calendar: Calendar = .current,
        options: ChronoPT.Options = ChronoPT.Options()
    ) -> [ChronoPT.Match] {
        parse(Context(text: text, reference: reference, calendar: calendar, options: options))
    }

    static func parse(_ context: Context) -> [ChronoPT.Match] {
        var results: [ChronoPT.Match] = []
        var usedTimes = Set<Int>()

        for day in context.days {
            let adjacent = context.times.indices.first { index in
                !usedTimes.contains(index) && context.fits(context.times[index], with: day)
                    && context.source.onlyConnectors(between: day.range, and: context.times[index].range)
            }
            if let adjacent { usedTimes.insert(adjacent) }
            if let result = context.combine(day, adjacent.map { context.times[$0] }) {
                results.append(result)
            }
        }
        for index in context.times.indices where !usedTimes.contains(index) {
            if let result = context.combine(nil, context.times[index]) {
                results.append(result)
            }
        }
        return results.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// The date the whole text points to: the first day mentioned, at the
    /// time next to it or, if there is none, at the first time mentioned in
    /// the text. Made for notes and reminders: "amanhã comprar pão no almoço"
    /// is tomorrow at 12:00.
    ///
    /// A part of the day next to the day also settles a clock time said further
    /// on, when both fall in the same half of the day: "amanhã de manhã,
    /// reunião às 7" is tomorrow at 7:00.
    ///
    /// When the day and the time are apart, `range` covers only the day.
    public static func interpret(
        _ text: String,
        reference: Date = .now,
        calendar: Calendar = .current,
        options: ChronoPT.Options = ChronoPT.Options()
    ) -> ChronoPT.Match? {
        interpret(Context(text: text, reference: reference, calendar: calendar, options: options))
    }

    static func interpret(_ context: Context) -> ChronoPT.Match? {
        guard let day = context.days.first(where: { context.resolve($0) != nil }) else {
            return context.times.lazy.compactMap { context.combine(nil, $0) }.first
        }
        let attached = context.times.first {
            context.fits($0, with: day) && context.source.onlyConnectors(between: day.range, and: $0.range)
        }
        // A time next to another day is that day's: in "amanhã comprar pão,
        // sexta às 14h dentista" the 14h is Friday's.
        let free = context.times.filter { time in
            !context.days.contains {
                $0.range != day.range && context.source.onlyConnectors(between: $0.range, and: time.range)
            }
        }
        let joined = attached.flatMap { attached in
            free.lazy.compactMap { TimeRules.joining(attached, $0) }.first
        }
        // A time counted from now belongs to no day: "consulta dia 30, sair
        // daqui a 20 minutos" is the 30th, not twenty minutes from now.
        return context.combine(day, joined ?? attached ?? free.first { context.fits($0, with: day) })
    }
}
