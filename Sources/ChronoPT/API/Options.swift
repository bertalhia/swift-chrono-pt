import Foundation

extension ChronoPT {
    /// How `parse` and `interpret` read the text.
    public struct Options: Sendable, Hashable, Codable {
        /// Read past dates: "ontem", "anteontem", "sexta passada", "na última
        /// sexta", "semana passada", "mês passado", "há 2 dias", "2 horas
        /// atrás". Off by default, since a reminder in the past is useless. A
        /// date that only names a day, such as "dia 15" or "na sexta", still
        /// means the next one.
        public var allowsPast: Bool

        /// The hour of a date the text gave without a time, from 0 to 23.
        /// Noon by default, away from the midnight shifts of daylight saving
        /// time.
        public var defaultHour: Int {
            get { hour }
            set { hour = Self.clamped(newValue) }
        }

        private var hour: Int

        /// Your app's own moments, with the time each one means: `["no
        /// treino": 7, "na consulta": TimeOfDay(hour: 14, minute: 30)!]`. They
        /// read like "no almoço": capitals and accents don't matter, and one
        /// wins over a built-in phrase written the same way. Of two keys that
        /// read the same, the first in key order wins.
        public var moments: [String: TimeOfDay]

        /// Options for reading text; see each property.
        public init(allowsPast: Bool = false, defaultHour: Int = 12, moments: [String: TimeOfDay] = [:]) {
            self.allowsPast = allowsPast
            self.hour = Self.clamped(defaultHour)
            self.moments = moments
        }

        private enum CodingKeys: String, CodingKey {
            case allowsPast, defaultHour, moments
            /// The key 0.x wrote for `defaultHour`.
            case hour
        }

        /// Reads `{"allowsPast": false, "defaultHour": 12, "moments": {"no
        /// treino": {"hour": 7, "minute": 0}}}`, and what 0.x wrote: `hour`
        /// for the default hour, whole hours for moments, no moments at all.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            allowsPast = try container.decodeIfPresent(Bool.self, forKey: .allowsPast) ?? false
            hour = Self.clamped(
                try container.decodeIfPresent(Int.self, forKey: .defaultHour)
                    ?? container.decodeIfPresent(Int.self, forKey: .hour) ?? 12)
            moments = try container.decodeIfPresent([String: TimeOfDay].self, forKey: .moments) ?? [:]
        }

        /// Writes `allowsPast`, `defaultHour` and `moments`.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(allowsPast, forKey: .allowsPast)
            try container.encode(defaultHour, forKey: .defaultHour)
            try container.encode(moments, forKey: .moments)
        }

        private static func clamped(_ hour: Int) -> Int {
            min(max(hour, 0), 23)
        }
    }
}
