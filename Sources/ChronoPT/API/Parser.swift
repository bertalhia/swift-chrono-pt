import Foundation

extension ChronoPT {
    /// A parser set up once with a calendar and options, for an app that reads
    /// many texts the same way. Only the reference date changes from call to
    /// call, and it defaults to now.
    ///
    /// ```swift
    /// let parser = ChronoPT.Parser(calendar: calendar, options: .init(defaultHour: 9))
    /// parser.interpret("pagar o aluguel dia 5")
    /// ```
    public struct Parser: Sendable, Hashable {
        /// Where midnight falls and which time zone the dates are in.
        public var calendar: Calendar
        public var options: Options

        public init(calendar: Calendar = .current, options: Options = Options()) {
            self.calendar = calendar
            self.options = options
        }

        /// Every date and time expression in the text, in the order they
        /// appear; see ``ChronoPT/parse(_:reference:calendar:options:)``.
        public func parse(_ text: String, reference: Date = .now) -> [Match] {
            ChronoPT.parse(text, reference: reference, calendar: calendar, options: options)
        }

        /// The date the whole text points to; see
        /// ``ChronoPT/interpret(_:reference:calendar:options:)``.
        public func interpret(_ text: String, reference: Date = .now) -> Match? {
            ChronoPT.interpret(text, reference: reference, calendar: calendar, options: options)
        }

        /// The text without the dates; see
        /// ``ChronoPT/strippingDates(from:reference:calendar:options:)``.
        public func strippingDates(from text: String, reference: Date = .now) -> String {
            ChronoPT.strippingDates(from: text, reference: reference, calendar: calendar, options: options)
        }
    }
}
