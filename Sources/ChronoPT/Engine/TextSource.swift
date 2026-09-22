import Foundation

/// The text as the rules read it: lowercase, without accents, punctuation
/// turned into spaces, and one character for each character of the original.
/// A position found here is the same position in the writer's text, and
/// "Almoço," matches "almoco".
///
/// Slash, colon and hyphen stay: "25/09", "10:30", "meio-dia". En and em
/// dashes become hyphens: "10h–11h", and ordinal indicators become the letter
/// they stand for: "1º" reads as "1o", "6ª" as "6a".
struct TextSource {
    let original: String
    let normalized: String

    init(_ text: String) {
        original = text
        normalized = String(
            text.map { character in
                let folded = String(character).folding(
                    options: [.diacriticInsensitive, .caseInsensitive],
                    locale: Locale(identifier: "pt_BR")
                )
                guard folded.count == 1, let simple = folded.first else { return character }
                if "–—".contains(simple) { return "-" }
                // Ordinal indicators read as the letter they stand for: "1º", "6ª".
                if simple == "º" { return "o" }
                if simple == "ª" { return "a" }
                return simple.isLetter || simple.isNumber || "/:-".contains(simple) ? simple : " "
            })
    }

    /// The same position in the original text.
    func originalRange(_ range: Range<String.Index>) -> Range<String.Index> {
        let start = normalized.distance(from: normalized.startIndex, to: range.lowerBound)
        let length = length(of: range)
        let lower = original.index(original.startIndex, offsetBy: start)
        return lower..<original.index(lower, offsetBy: length)
    }

    func length(of range: Range<String.Index>) -> Int {
        normalized.distance(from: range.lowerBound, to: range.upperBound)
    }

    /// Where the phrase appears as whole words: "a noite" does not match
    /// inside "da noite".
    func wordRanges(of phrase: String) -> [Range<String.Index>] {
        normalized.ranges(of: phrase).filter { range in
            let before =
                range.lowerBound > normalized.startIndex
                ? normalized[normalized.index(before: range.lowerBound)] : nil
            let after = range.upperBound < normalized.endIndex ? normalized[range.upperBound] : nil
            return !Self.isWordCharacter(before) && !Self.isWordCharacter(after)
        }
    }

    /// The word right before the position, for rules that depend on context:
    /// "por 2 horas" is a duration, not a time.
    func word(before index: String.Index) -> String? {
        wordRange(before: index).map { String(normalized[$0]) }
    }

    /// Where the word right before the position is.
    func wordRange(before index: String.Index) -> Range<String.Index>? {
        var end = index
        while end > normalized.startIndex, !Self.isWordCharacter(normalized[normalized.index(before: end)]) {
            end = normalized.index(before: end)
        }
        var start = end
        while start > normalized.startIndex, Self.isWordCharacter(normalized[normalized.index(before: start)])
        {
            start = normalized.index(before: start)
        }
        return start < end ? start..<end : nil
    }

    func words(in range: Range<String.Index>) -> [String] {
        normalized[range].split(whereSeparator: { !Self.isWordCharacter($0) }).map(String.init)
    }

    /// The words right after the position: "8h por dia" is a duration.
    func words(after index: String.Index, count: Int) -> [String] {
        normalized[index...]
            .split(maxSplits: count, whereSeparator: { !Self.isWordCharacter($0) })
            .prefix(count)
            .map(String.init)
    }

    /// Whether every word in the range passes, stopping at the first one that
    /// does not. The rules ask this about gaps that can be the whole text, so
    /// splitting the range first would make every question cost its length.
    func everyWord(in range: Range<String.Index>, _ isAllowed: (Substring) -> Bool) -> Bool {
        var index = range.lowerBound
        while index < range.upperBound {
            guard Self.isWordCharacter(normalized[index]) else {
                index = normalized.index(after: index)
                continue
            }
            var end = index
            while end < range.upperBound, Self.isWordCharacter(normalized[end]) {
                end = normalized.index(after: end)
            }
            guard isAllowed(normalized[index..<end]) else { return false }
            index = end
        }
        return true
    }

    /// Whether the range holds no word at all.
    func hasNoWord(in range: Range<String.Index>) -> Bool {
        !normalized[range].contains(where: Self.isWordCharacter)
    }

    /// Only spaces and prepositions between the two ranges: "amanhã às 9",
    /// "sexta à noite", "hoje, no almoço".
    func onlyConnectors(between first: Range<String.Index>, and second: Range<String.Index>) -> Bool {
        let (left, right) = first.lowerBound <= second.lowerBound ? (first, second) : (second, first)
        guard left.upperBound <= right.lowerBound else { return true }
        return everyWord(in: left.upperBound..<right.lowerBound) { Self.connectors.contains(String($0)) }
    }

    /// Where a range from `first` to `second` starts, or nil when the words
    /// around them don't make one. It opens with "de", "do", "da", "das",
    /// "desde" or "entre", right before `first` or as its first word ("das
    /// 14h"); with `bareStart`, when `first` starts right at its number or name
    /// ("14h às 16h", "segunda a sexta"), it needs no opening word. It closes
    /// with "a" or "até", or "e" after "entre", between the two or as the first
    /// word of `second` ("às 16h", "até sexta"), or with a hyphen alone
    /// ("10h-11h", "seg-sex"). Articles may sit in between: "de hoje até o
    /// dia 30".
    func rangeStart(from first: Range<String.Index>, to second: Range<String.Index>, bareStart: Bool = false)
        -> String.Index?
    {
        guard first.upperBound <= second.lowerBound else { return nil }
        var opening: (word: String, start: String.Index)?
        if let word = words(after: first.lowerBound, count: 1).first, Self.rangeOpenings.contains(word) {
            opening = (word, first.lowerBound)
        } else if let before = wordRange(before: first.lowerBound),
            Self.rangeOpenings.contains(String(normalized[before]))
        {
            opening = (String(normalized[before]), before.lowerBound)
        }
        guard opening != nil || bareStart else { return nil }
        let start = opening?.start ?? first.lowerBound
        let gap = first.upperBound..<second.lowerBound
        // "de segunda e quarta" is two days, not a range.
        let closings: Set<String> = opening?.word == "entre" ? ["e"] : ["a", "as", "ao", "ate"]
        guard everyWord(in: gap, { closings.contains(String($0)) || Self.articles.contains(String($0)) })
        else { return nil }
        if hasNoWord(in: gap), normalized[gap].contains("-") { return start }
        let between = words(in: gap)
        guard (between + words(after: second.lowerBound, count: 1)).contains(where: closings.contains)
        else { return nil }
        return start
    }

    /// The range starts right at a number: "14h", "10/10".
    func startsWithNumber(_ range: Range<String.Index>) -> Bool {
        words(after: range.lowerBound, count: 1).first?.first?.isNumber ?? false
    }

    private static let rangeOpenings: Set<String> = ["de", "do", "da", "das", "desde", "entre"]
    private static let articles: Set<String> = ["o", "a", "os", "as"]

    private static let connectors: Set<String> = [
        "a", "as", "ao", "ate", "de", "do", "da", "no", "na", "pela", "pelo", "e", "la", "por", "volta",
    ]

    private static func isWordCharacter(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character.isLetter || character.isNumber
    }
}
