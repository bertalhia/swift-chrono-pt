import Foundation

extension ChronoPT {
    /// How a date repeats, in the terms of an iCalendar rule (RFC 5545), which
    /// is also what `EKRecurrenceRule` takes.
    ///
    /// The text decides only what it says. "toda semana" leaves `weekdays`
    /// empty: the start date's weekday repeats. One reading has one value:
    /// "diariamente" and "a cada 1 dia" are both `.daily()`.
    public struct Recurrence: Sendable, Hashable, Codable {
        /// The unit the rule repeats in.
        public enum Frequency: String, Sendable, Hashable, Codable, CaseIterable {
            case minutely, hourly, daily, weekly, monthly, yearly
        }

        /// Where a rule stops.
        public enum End: Sendable, Hashable, Codable {
            /// No occurrence after this moment, the end of the last day the
            /// text allows: "até dezembro" is 31 December at 23:59:59.
            case until(Date)
            /// This many occurrences in all: "5 vezes".
            case count(Int)
        }

        public var frequency: Frequency

        /// Every how many units: 2 for "de 2 em 2 semanas".
        public var interval: Int

        /// The weekdays it falls on: "às segundas e quartas". Empty when the
        /// start date decides.
        public var weekdays: Set<Locale.Weekday>

        /// Which of `weekdays` in the month, for a monthly rule: 1 for the
        /// first, -1 for the last. "toda última sexta do mês" is -1.
        public var weekdayOrdinal: Int?

        /// The days of the month: "todo dia 5".
        public var daysOfMonth: Set<Int>

        /// The months, 1 to 12, for a yearly rule: "todo ano em julho".
        public var months: Set<Int>

        /// How many times in each unit, when the text gave no hours: "3x ao
        /// dia" is 3. An app picks the times; RFC 5545 has no field for it.
        public var timesPerPeriod: Int?

        /// Where it stops: "até dezembro", "por 10 dias", "5 vezes".
        public var end: End?

        public init(
            frequency: Frequency,
            interval: Int = 1,
            weekdays: Set<Locale.Weekday> = [],
            weekdayOrdinal: Int? = nil,
            daysOfMonth: Set<Int> = [],
            months: Set<Int> = [],
            timesPerPeriod: Int? = nil,
            end: End? = nil
        ) {
            self.frequency = frequency
            self.interval = max(1, interval)
            self.weekdays = weekdays
            self.weekdayOrdinal = weekdayOrdinal
            self.daysOfMonth = daysOfMonth
            self.months = months
            self.timesPerPeriod = timesPerPeriod
            self.end = end
        }

        /// Every day, or every few days: "todo dia", "a cada 15 dias".
        public static func daily(every interval: Int = 1) -> Self {
            Self(frequency: .daily, interval: interval)
        }

        /// Every week, on these weekdays or on the start date's: "toda terça",
        /// "às segundas e quartas", "de 2 em 2 semanas".
        public static func weekly(every interval: Int = 1, on weekdays: Set<Locale.Weekday> = []) -> Self {
            Self(frequency: .weekly, interval: interval, weekdays: weekdays)
        }

        /// Every month, on this day or on the start date's: "todo dia 5",
        /// "todo mês".
        public static func monthly(every interval: Int = 1, day: Int? = nil) -> Self {
            Self(frequency: .monthly, interval: interval, daysOfMonth: day.map { [$0] } ?? [])
        }

        /// Every year: "todo ano", "a cada 2 anos".
        public static func yearly(every interval: Int = 1) -> Self {
            Self(frequency: .yearly, interval: interval)
        }

        /// Every few hours: "de 8 em 8 horas".
        public static func hourly(every interval: Int = 1) -> Self {
            Self(frequency: .hourly, interval: interval)
        }

        /// Every few minutes: "a cada 30 minutos".
        public static func minutely(every interval: Int = 1) -> Self {
            Self(frequency: .minutely, interval: interval)
        }

        /// The rule as an RFC 5545 `RRULE` value, for iCalendar files and
        /// calendar servers: "FREQ=WEEKLY;BYDAY=MO,WE". `timesPerPeriod` has
        /// no place in it and is left out.
        public var rrule: String {
            var parts = ["FREQ=" + frequency.rawValue.uppercased()]
            if interval > 1 { parts.append("INTERVAL=\(interval)") }
            if !weekdays.isEmpty {
                let prefix = weekdayOrdinal.map(String.init) ?? ""
                let days = Self.weekOrder.filter(weekdays.contains).compactMap { Self.codes[$0] }
                parts.append("BYDAY=" + days.map { prefix + $0 }.joined(separator: ","))
            }
            if !daysOfMonth.isEmpty {
                parts.append("BYMONTHDAY=" + daysOfMonth.sorted().map(String.init).joined(separator: ","))
            }
            if !months.isEmpty {
                parts.append("BYMONTH=" + months.sorted().map(String.init).joined(separator: ","))
            }
            switch end {
            case .count(let count): parts.append("COUNT=\(count)")
            case .until(let date): parts.append("UNTIL=" + Self.utc(date))
            case nil: break
            }
            return parts.joined(separator: ";")
        }

        private static let weekOrder: [Locale.Weekday] = [
            .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
        ]

        private static let codes: [Locale.Weekday: String] = [
            .monday: "MO", .tuesday: "TU", .wednesday: "WE", .thursday: "TH", .friday: "FR",
            .saturday: "SA", .sunday: "SU",
        ]

        /// "20261231T235959Z".
        private static func utc(_ date: Date) -> String {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let fields = [parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second].map {
                $0 ?? 0
            }
            return String(
                format: "%04ld%02ld%02ldT%02ld%02ld%02ldZ", fields[0], fields[1], fields[2], fields[3],
                fields[4],
                fields[5])
        }
    }
}

extension ChronoPT.Recurrence {
    /// The rule for "a cada 15 dias", "de 8 em 8 horas": the one unit the
    /// components name, and how many of it.
    init?(every components: DateComponents) {
        let units: [(Int?, Frequency)] = [
            (components.minute, .minutely), (components.hour, .hourly), (components.day, .daily),
            (components.weekOfYear, .weekly), (components.month, .monthly), (components.year, .yearly),
        ]
        guard
            let (count, frequency) = units.lazy.compactMap({ count, unit in count.map { ($0, unit) } }).first
        else { return nil }
        self.init(frequency: frequency, interval: count)
    }
}

extension ChronoPT.Recurrence: CustomStringConvertible {
    /// The `rrule`, with the times per period when there are any; stable, for
    /// logs and bug reports.
    public var description: String {
        rrule + (timesPerPeriod.map { " (\($0) times each)" } ?? "")
    }
}
