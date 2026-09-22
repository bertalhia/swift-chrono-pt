import Foundation

extension ChronoPT {
    /// How a date repeats, in the terms of an iCalendar rule (RFC 5545), which
    /// is also what `EKRecurrenceRule` and `Calendar.RecurrenceRule` take.
    ///
    /// The text decides only what it says. "toda semana" leaves `weekdays`
    /// empty: the start date's weekday repeats. One reading has one value:
    /// "diariamente" and "a cada 1 dia" are both `.daily()`.
    ///
    /// The `Codable` form is stable: it keeps its keys, writes sets in order,
    /// and refuses values no rule can hold.
    public struct Recurrence: Sendable, Hashable, Codable {
        /// The unit the rule repeats in. The six cases are the ones RFC 5545
        /// and Foundation share, and the set is closed.
        public enum Frequency: String, Sendable, Hashable, Codable, CaseIterable {
            /// Every so many minutes: "a cada 30 minutos".
            case minutely
            /// Every so many hours: "de 8 em 8 horas".
            case hourly
            /// Every so many days: "todo dia", "dia sim, dia não".
            case daily
            /// Every so many weeks: "toda terça", "de 2 em 2 semanas".
            case weekly
            /// Every so many months: "todo dia 5", "toda última sexta do mês".
            case monthly
            /// Every so many years: "todo 25 de dezembro".
            case yearly
        }

        /// Where a rule stops. The two cases are RFC 5545's, and the set is
        /// closed.
        public enum End: Sendable, Hashable, Codable {
            /// No occurrence after this moment, the end of the last day the
            /// text allows: "até dezembro" is 31 December at 23:59:59.
            case until(Date)
            /// This many occurrences in all: "5 vezes".
            case count(Int)

            private enum CodingKeys: String, CodingKey {
                case until, count
            }

            /// `{"until": <date>}` or `{"count": 5}`.
            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let date = try container.decodeIfPresent(Date.self, forKey: .until) {
                    self = .until(date)
                } else {
                    let count = try container.decode(Int.self, forKey: .count)
                    guard count > 0 else {
                        throw DecodingError.dataCorruptedError(
                            forKey: .count, in: container, debugDescription: "A count is at least 1")
                    }
                    self = .count(count)
                }
            }

            /// Writes `{"until": <date>}` or `{"count": 5}`.
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .until(let date): try container.encode(date, forKey: .until)
                case .count(let count): try container.encode(count, forKey: .count)
                }
            }
        }

        /// A weekday the rule falls on, every time or in one place in the
        /// month: "toda segunda" is every Monday, "toda última sexta do mês"
        /// the Friday at -1.
        public struct Weekday: Sendable, Hashable, Codable {
            /// Monday to Sunday.
            public var weekday: Locale.Weekday
            /// 1 for the first in the month, -1 for the last; `nil` for every
            /// one.
            public var ordinal: Int?

            /// That weekday, every one or in one place; see ``every(_:)`` and
            /// ``nth(_:_:)``.
            public init(_ weekday: Locale.Weekday, ordinal: Int? = nil) {
                self.weekday = weekday
                self.ordinal = ordinal
            }

            /// Every one of that weekday: "toda segunda".
            public static func every(_ weekday: Locale.Weekday) -> Self {
                Self(weekday)
            }

            /// That weekday in one place: `.nth(-1, .friday)` is "a última
            /// sexta".
            public static func nth(_ ordinal: Int, _ weekday: Locale.Weekday) -> Self {
                Self(weekday, ordinal: ordinal)
            }
        }

        /// How many times in each unit when the text gave no hours: "3x ao
        /// dia" is 3 per day, also inside a weekly rule ("toda terça, 3 vezes
        /// ao dia"). RFC 5545 has no field for it; an app picks the hours.
        public struct Rate: Sendable, Hashable, Codable {
            /// How many times, at least 1.
            public var count: Int
            /// In each of which unit: `.daily` for "ao dia".
            public var per: Frequency

            /// A count in each unit; a count below 1 gives 1.
            public init(count: Int, per: Frequency) {
                self.count = max(1, count)
                self.per = per
            }
        }

        /// The unit it repeats in: days for "todo dia", weeks for "toda terça".
        public var frequency: Frequency

        /// Every how many units, at least 1: 2 for "de 2 em 2 semanas".
        public var interval: Int {
            get { storedInterval }
            set { storedInterval = max(1, newValue) }
        }

        private var storedInterval: Int

        /// The weekdays it falls on: "às segundas e quartas". Empty when the
        /// start date decides.
        public var weekdays: Set<Weekday>

        /// The days of the month, 1 to 31, or -1 for the last: "todo dia 5".
        public var daysOfMonth: Set<Int>

        /// The months, 1 to 12, for a yearly rule: "todo ano em julho".
        public var months: Set<Int>

        /// The times it happens on each day it falls on: "todo dia às 8h e às
        /// 20h". Empty when the start date's time is the one.
        public var timesOfDay: Set<TimeOfDay>

        /// How many times in each unit, when the text gave a count and no
        /// hours: "3x ao dia".
        public var rate: Rate?

        /// Where it stops: "até dezembro", "por 10 dias", "5 vezes".
        public var end: End?

        /// A rule with these fields; an interval below 1 gives 1. The static
        /// factories build the common ones: ``daily(every:)``,
        /// ``weekly(every:on:)``, ``monthly(every:day:)``.
        public init(
            frequency: Frequency,
            interval: Int = 1,
            weekdays: Set<Weekday> = [],
            daysOfMonth: Set<Int> = [],
            months: Set<Int> = [],
            timesOfDay: Set<TimeOfDay> = [],
            rate: Rate? = nil,
            end: End? = nil
        ) {
            self.frequency = frequency
            self.storedInterval = max(1, interval)
            self.weekdays = weekdays
            self.daysOfMonth = daysOfMonth
            self.months = months
            self.timesOfDay = timesOfDay
            self.rate = rate
            self.end = end
        }

        /// Every day, or every few days: "todo dia", "a cada 15 dias".
        public static func daily(every interval: Int = 1) -> Self {
            Self(frequency: .daily, interval: interval)
        }

        /// Every week, on these weekdays or on the start date's: "toda terça",
        /// "às segundas e quartas", "de 2 em 2 semanas".
        public static func weekly(every interval: Int = 1, on weekdays: Set<Locale.Weekday> = []) -> Self {
            Self(frequency: .weekly, interval: interval, weekdays: Set(weekdays.map(Weekday.every)))
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
        /// calendar servers: "FREQ=WEEKLY;BYDAY=MO,WE". This string is stable.
        ///
        /// `rate` has no place in it. `timesOfDay` becomes `BYHOUR` and
        /// `BYMINUTE` when every hour goes with every minute (8:00 and 20:00);
        /// times that don't combine that way (8:00 and 20:30) are left out.
        public var rrule: String {
            var parts = ["FREQ=" + frequency.rawValue.uppercased()]
            if interval > 1 { parts.append("INTERVAL=\(interval)") }
            if !weekdays.isEmpty {
                let days = Self.sorted(weekdays).map { day in
                    (day.ordinal.map(String.init) ?? "") + (Self.codes[day.weekday] ?? "")
                }
                parts.append("BYDAY=" + days.joined(separator: ","))
            }
            if !daysOfMonth.isEmpty { parts.append("BYMONTHDAY=" + Self.list(daysOfMonth)) }
            if !months.isEmpty { parts.append("BYMONTH=" + Self.list(months)) }
            let hours = Set(timesOfDay.map(\.hour))
            let minutes = Set(timesOfDay.map(\.minute))
            if !timesOfDay.isEmpty, hours.count * minutes.count == timesOfDay.count {
                parts.append("BYHOUR=" + Self.list(hours))
                parts.append("BYMINUTE=" + Self.list(minutes))
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

        /// Week order from Monday, then place in the month.
        private static func sorted(_ weekdays: Set<Weekday>) -> [Weekday] {
            weekdays.sorted { lhs, rhs in
                let left = weekOrder.firstIndex(of: lhs.weekday) ?? 0
                let right = weekOrder.firstIndex(of: rhs.weekday) ?? 0
                return left != right ? left < right : (lhs.ordinal ?? 0) < (rhs.ordinal ?? 0)
            }
        }

        private static func list(_ values: Set<Int>) -> String {
            values.sorted().map(String.init).joined(separator: ",")
        }

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
                fields[4], fields[5])
        }

        // MARK: Codable

        private enum CodingKeys: String, CodingKey {
            case frequency, interval, weekdays, daysOfMonth, months, timesOfDay, rate, end
        }

        /// Reads the form ``encode(to:)`` writes, and throws a
        /// `DecodingError` for a value no rule can hold.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            func refuse(_ key: CodingKeys, _ reason: String) -> DecodingError {
                .dataCorruptedError(forKey: key, in: container, debugDescription: reason)
            }
            frequency = try container.decode(Frequency.self, forKey: .frequency)
            let interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 1
            guard interval >= 1 else { throw refuse(.interval, "An interval is at least 1") }
            storedInterval = interval
            weekdays = Set(try container.decodeIfPresent([Weekday].self, forKey: .weekdays) ?? [])
            guard weekdays.allSatisfy({ $0.ordinal.map { $0 != 0 && (-53...53).contains($0) } ?? true })
            else {
                throw refuse(.weekdays, "A weekday's place is 1 to 53 or -1 to -53")
            }
            daysOfMonth = Set(try container.decodeIfPresent([Int].self, forKey: .daysOfMonth) ?? [])
            guard daysOfMonth.allSatisfy({ $0 != 0 && (-31...31).contains($0) }) else {
                throw refuse(.daysOfMonth, "A day of the month is 1 to 31 or -1 to -31")
            }
            months = Set(try container.decodeIfPresent([Int].self, forKey: .months) ?? [])
            guard months.allSatisfy((1...12).contains) else { throw refuse(.months, "A month is 1 to 12") }
            timesOfDay = Set(try container.decodeIfPresent([TimeOfDay].self, forKey: .timesOfDay) ?? [])
            rate = try container.decodeIfPresent(Rate.self, forKey: .rate)
            guard (rate?.count ?? 1) >= 1 else { throw refuse(.rate, "A rate is at least 1") }
            end = try container.decodeIfPresent(End.self, forKey: .end)
        }

        /// Sets are written in order, so the same rule always gives the same
        /// bytes.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(frequency, forKey: .frequency)
            try container.encode(interval, forKey: .interval)
            try container.encode(Self.sorted(weekdays), forKey: .weekdays)
            try container.encode(daysOfMonth.sorted(), forKey: .daysOfMonth)
            try container.encode(months.sorted(), forKey: .months)
            try container.encode(timesOfDay.sorted(), forKey: .timesOfDay)
            try container.encodeIfPresent(rate, forKey: .rate)
            try container.encodeIfPresent(end, forKey: .end)
        }
    }
}

extension ChronoPT.Recurrence {
    /// The rule for "a cada 15 dias", "de 8 em 8 horas": the one unit the
    /// components name, and how many of it.
    init?(every components: DateComponents) {
        guard let (count, frequency) = Self.unit(of: components) else { return nil }
        self.init(frequency: frequency, interval: count)
    }

    /// The unit and count a `DateComponents` names.
    static func unit(of components: DateComponents) -> (Int, Frequency)? {
        let units: [(Int?, Frequency)] = [
            (components.minute, .minutely), (components.hour, .hourly), (components.day, .daily),
            (components.weekOfYear, .weekly), (components.month, .monthly), (components.year, .yearly),
        ]
        return units.lazy.compactMap { count, unit in count.map { ($0, unit) } }.first
    }
}

extension ChronoPT.Recurrence: CustomStringConvertible {
    /// The `rrule`, with the rate when there is one: "FREQ=DAILY (3 per
    /// day)". For logs and bug reports; `rrule` is the stable form.
    public var description: String {
        rrule + (rate.map { " (\($0.count) per \(Self.unitNames[$0.per] ?? ""))" } ?? "")
    }

    private static let unitNames: [Frequency: String] = [
        .minutely: "minute", .hourly: "hour", .daily: "day", .weekly: "week", .monthly: "month",
        .yearly: "year",
    ]
}
