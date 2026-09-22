import Foundation

extension ChronoPT {
    /// A clock time with no day: 7:00, 18:30.
    ///
    /// An integer literal is a whole hour, so `["no treino": 7]` reads as 7:00.
    /// It encodes as `{"hour": 18, "minute": 30}` and also decodes from a bare
    /// hour, `7`.
    public struct TimeOfDay: Sendable, Hashable, Comparable, Codable, ExpressibleByIntegerLiteral,
        CustomStringConvertible
    {
        /// From 0 to 23.
        public let hour: Int
        /// From 0 to 59.
        public let minute: Int

        /// A time of day; `nil` when the hour is outside 0 to 23 or the minute
        /// outside 0 to 59.
        public init?(hour: Int, minute: Int = 0) {
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            self.hour = hour
            self.minute = minute
        }

        /// A whole hour, from 0 to 23; a literal outside that range is a
        /// programming error.
        public init(integerLiteral hour: Int) {
            precondition((0...23).contains(hour), "An hour is 0 to 23, not \(hour)")
            self.hour = hour
            self.minute = 0
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
        }

        /// "07:00", "18:30".
        public var description: String {
            String(format: "%02ld:%02ld", hour, minute)
        }

        private enum CodingKeys: String, CodingKey {
            case hour, minute
        }

        public init(from decoder: any Decoder) throws {
            if let hour = try? decoder.singleValueContainer().decode(Int.self) {
                guard let time = Self(hour: hour) else {
                    throw DecodingError.dataCorrupted(
                        .init(
                            codingPath: decoder.codingPath,
                            debugDescription: "Hour \(hour) is outside 0 to 23"))
                }
                self = time
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decodeIfPresent(Int.self, forKey: .minute) ?? 0
            guard let time = Self(hour: hour, minute: minute) else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "\(hour):\(minute) is not a time of day"))
            }
            self = time
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
        }
    }
}
