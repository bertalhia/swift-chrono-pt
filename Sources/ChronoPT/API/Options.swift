import Foundation

extension ChronoPT {
    /// How `parse` and `interpret` read the text.
    public struct Options: Sendable, Hashable, Codable {
        /// Read past dates: "ontem", "anteontem", "sexta passada", "na última
        /// sexta", "semana passada", "mês passado", "há 2 dias", "2 horas
        /// atrás". Off by default, since a reminder in the past is useless. A
        /// date that only names a day, such as "dia 15" or "sexta", still
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

        /// Your app's own moments, with the hour each one means: `["no
        /// treino": 7, "na consulta": 14]`. They read like "no almoço":
        /// capitals and accents don't matter, and one wins over a built-in
        /// phrase written the same way. An hour outside 0 to 23 is ignored.
        public var moments: [String: Int]

        public init(allowsPast: Bool = false, defaultHour: Int = 12, moments: [String: Int] = [:]) {
            self.allowsPast = allowsPast
            self.hour = Self.clamped(defaultHour)
            self.moments = moments
        }

        private enum CodingKeys: String, CodingKey {
            case allowsPast, hour, moments
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            allowsPast = try container.decode(Bool.self, forKey: .allowsPast)
            hour = Self.clamped(try container.decode(Int.self, forKey: .hour))
            // Options saved before moments existed have none.
            moments = try container.decodeIfPresent([String: Int].self, forKey: .moments) ?? [:]
        }

        private static func clamped(_ hour: Int) -> Int {
            min(max(hour, 0), 23)
        }
    }
}
