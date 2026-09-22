import Foundation
import Testing

@testable import ChronoPT

/// The integration snippets in the README and the DocC recipes, compiled and
/// run, so they cannot drift from the API.
@Suite("Integration recipes")
struct IntegrationTests {
    @Test("NSRange for UIKit highlighting")
    func nsRange() throws {
        let text = "dentista amanhã às 9"
        let match = try #require(interpret(text))
        let range = NSRange(match.range, in: text)
        #expect((text as NSString).substring(with: range) == "amanhã às 9")
    }

    #if canImport(Darwin)
        @Test("AttributedString highlighting for SwiftUI")
        func attributedString() throws {
            let text = "dentista amanhã às 9, reunião sexta"
            var attributed = AttributedString(text)
            for match in parse(text) {
                for range in match.ranges {
                    guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                        let upper = AttributedString.Index(range.upperBound, within: attributed)
                    else { continue }
                    attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
                }
            }
            let emphasized = attributed.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }
            #expect(emphasized.map { String(attributed[$0.range].characters) } == ["amanhã às 9", "sexta"])
        }
    #endif
}
