import Foundation

extension ChronoPT {
    /// A date expression found in the text.
    public struct Match: Sendable, Hashable {
        /// Where the expression is in the input text: the day, with the time
        /// when the two are next to each other.
        public let range: Range<String.Index>

        /// Every span that produced this date, in text order. A time said
        /// apart from its day ("amanhã de manhã, reunião às 7") has a span of
        /// its own, which is what a highlight or a text cleanup needs.
        public let ranges: [Range<String.Index>]

        /// The expression as written in the text, the part `range` covers.
        public let text: String

        /// When it starts.
        public let start: PartialDate

        /// When it ends, for a period or a range: "semana que vem", "de
        /// segunda a sexta", "das 14h às 16h".
        public let end: PartialDate?

        /// How the date repeats, for "toda terça", "todo dia às 8" or "todo
        /// dia 5"; `nil` for a single date. `start` is the next time it
        /// happens.
        public let recurrence: ChronoPT.Recurrence?

        /// Whether the text asks for the whole day: "amanhã o dia todo",
        /// "sexta, dia inteiro". `start` still has no time, so a
        /// calendar app can make an all-day event.
        public let isAllDay: Bool

        public init(
            range: Range<String.Index>,
            ranges: [Range<String.Index>]? = nil,
            text: String,
            start: PartialDate,
            end: PartialDate? = nil,
            recurrence: ChronoPT.Recurrence? = nil,
            isAllDay: Bool = false
        ) {
            self.range = range
            self.ranges = ranges ?? [range]
            self.text = text
            self.start = start
            self.end = end
            self.recurrence = recurrence
            self.isAllDay = isAllDay
        }

        /// From the start to the end, for an expression that has an end.
        public var interval: DateInterval? {
            guard let end, end.date > start.date else { return nil }
            return DateInterval(start: start.date, end: end.date)
        }
    }

    /// A point in time found in the text, and which of its parts the text
    /// gave.
    public struct PartialDate: Sendable, Hashable {
        /// The date. With no time in the text, it is noon of that day, or
        /// ``ChronoPT/Options/defaultHour``.
        public let date: Date

        /// The calendar components the text fixes, by naming them ("25/09"
        /// names the day and the month) or by counting from the reference date
        /// ("amanhã" fixes the day, the month and the year).
        ///
        /// The other components come from the reference date or from defaults:
        /// the year of "25/09", the hour of a day with no time, the day of a
        /// time with no day. A part of the day such as "de manhã" gives
        /// `.hour` but not `.minute`, and a weekday adds `.weekday`.
        public let knownComponents: Set<Calendar.Component>

        /// The other reading of an hour that did not say morning or evening:
        /// "às 7" is 19:00, and 7:00 is the alternative, the next time it
        /// comes. `nil` when the text settled it ("às 7 da manhã", "de manhã,
        /// às 7", "7h", "14h") or gave no hour. A UI can offer it as a choice.
        public let alternative: Date?

        public init(date: Date, knownComponents: Set<Calendar.Component>, alternative: Date? = nil) {
            self.date = date
            self.knownComponents = knownComponents
            self.alternative = alternative
        }

        /// Whether the text gave a time: "às 9", "de manhã", "daqui 2 horas".
        public var hasTime: Bool {
            knownComponents.contains(.hour)
        }

        /// Whether the text gave a day: "amanhã", "25/09", "sexta".
        public var hasDay: Bool {
            knownComponents.contains(.day)
        }

        /// Only the components the text gave, for showing "25/09" without
        /// inventing a year.
        public func dateComponents(in calendar: Calendar) -> DateComponents {
            calendar.dateComponents(knownComponents, from: date)
        }
    }
}

extension ChronoPT.Match {
    /// The same match with another reading of its start.
    func with(alternative: Date?) -> Self {
        Self(
            range: range, ranges: ranges, text: text,
            start: ChronoPT.PartialDate(
                date: start.date, knownComponents: start.knownComponents, alternative: alternative),
            end: end, recurrence: recurrence, isAllDay: isAllDay)
    }
}

extension ChronoPT.Match: CustomDebugStringConvertible {
    public var debugDescription: String {
        let ending = end.map { " to \($0.date.ISO8601Format())" } ?? ""
        let repeating = recurrence.map { ", repeating \($0)" } ?? ""
        let allDay = isAllDay ? ", all day" : ""
        return "\"\(text)\" → \(start.date.ISO8601Format())\(ending)\(repeating)\(allDay)"
    }
}
