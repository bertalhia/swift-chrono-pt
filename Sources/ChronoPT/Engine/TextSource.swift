import Foundation

/// The text as the rules read it: lowercase, without accents, punctuation
/// turned into spaces, and one character for each character of the original.
/// A position found here is the same position in the writer's text, and
/// "Almoço," matches "almoco".
///
/// Slash, colon and hyphen stay: "25/09", "10:30", "meio-dia", and so do a
/// dot between digits, "25.12.2027", and a plus before one, "GMT+1". En and em
/// dashes become hyphens: "10h–11h", and ordinal indicators become the letter
/// they stand for: "1º" reads as "1o", "6ª" as "6a".
struct TextSource {
    let original: String
    let normalized: String

    /// Every word in the text, so a rule can tell at once that its regex has
    /// nothing to find.
    let words: Set<String>
    let hasDigit: Bool

    /// Where each word is: its places among the words of the text.
    private let places: [String: [Int]]
    /// Where each word starts, in text order.
    private let wordStarts: [String.Index]
    /// The places of the words with a digit.
    private let digitWords: [Int]

    /// Whether a rule skips its regex when none of its words is in the text.
    /// Off only in the test that proves skipping changes no result.
    let skipsRules: Bool

    init(_ text: String, skipsRules: Bool = true) {
        original = text
        var mapped: [Character] = []
        mapped.reserveCapacity(text.utf8.count)
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            // A dot between digits and a plus before one stay, so
            // "25.12.2027", "14:30:00+01:00" and "GMT+1" keep their shape;
            // anywhere else they are punctuation.
            let digitAfter =
                index + 1 < characters.count && characters[index + 1].isASCII
                && characters[index + 1].isNumber
            let digitBefore = index > 0 && characters[index - 1].isASCII && characters[index - 1].isNumber
            if digitAfter && (character == "+" || (character == "." && digitBefore)) {
                mapped.append(character)
            } else {
                mapped.append(Self.normalized(character))
            }
        }
        var normalized = String(mapped)
        if normalized.count != mapped.count {
            Self.separate(&mapped)
            normalized = String(mapped)
        }
        self.normalized = normalized
        self.cursor = Cursor(normalized: normalized.startIndex, original: text.startIndex)
        self.skipsRules = skipsRules
        var places: [String: [Int]] = [:]
        var wordStarts: [String.Index] = []
        var digitWords: [Int] = []
        for word in normalized.split(whereSeparator: { !Self.isWordCharacter($0) }) {
            places[String(word), default: []].append(wordStarts.count)
            if word.contains(where: \.isNumber) { digitWords.append(wordStarts.count) }
            wordStarts.append(word.startIndex)
        }
        self.words = Set(places.keys)
        self.hasDigit = !digitWords.isEmpty
        self.places = places
        self.wordStarts = wordStarts
        self.digitWords = digitWords
        self.sentenceBreaks = Self.sentenceBreaks(in: characters, normalized: normalized)
    }

    /// Where a sentence ends: a line break, "!", "?", ";", or a full stop
    /// before a capital letter or a line break. A full stop before a lowercase
    /// word is an abbreviation: "seg. às 10", "5 de out. às 9".
    let sentenceBreaks: [String.Index]

    private static func sentenceBreaks(in characters: [Character], normalized: String) -> [String.Index] {
        var breaks: [String.Index] = []
        var position = normalized.startIndex
        for (index, character) in characters.enumerated() {
            defer { position = normalized.index(after: position) }
            guard normalized[position] == " " else { continue }
            if character.isNewline || "!?;".contains(character) {
                breaks.append(position)
            } else if character == "." {
                let next = characters[(index + 1)...].first { $0 != " " && $0 != "\t" }
                if next.map({ $0.isNewline || $0.isUppercase }) ?? true { breaks.append(position) }
            }
        }
        return breaks
    }

    /// Whether a sentence ends inside the range.
    func hasSentenceBreak(in range: Range<String.Index>) -> Bool {
        var low = 0
        var high = sentenceBreaks.count
        while low < high {
            let middle = (low + high) / 2
            if sentenceBreaks[middle] < range.lowerBound { low = middle + 1 } else { high = middle }
        }
        return low < sentenceBreaks.count && sentenceBreaks[low] < range.upperBound
    }

    /// The regex's matches, or none without running it when the text holds
    /// none of the words every one of its matches needs. A regex pass costs
    /// its length in the text; a set lookup costs nothing.
    ///
    /// Every match holds one of those words, a few words at most after where
    /// it starts, so the regex is tried only at the starts of the words just
    /// before each of them, instead of at every position of the text. The
    /// equivalence test in `PrefilterTests` runs every parse both ways.
    func matches<Output>(
        of regex: @autoclosure () -> Regex<Output>,
        whenAny triggers: Set<String>,
        orDigit: Bool = false
    ) -> [Regex<Output>.Match] {
        guard skipsRules else { return normalized.matches(of: regex()) }
        var found = triggers.flatMap { places[$0] ?? [] }
        if orDigit { found += digitWords }
        guard !found.isEmpty else { return [] }
        var starts = Set<Int>()
        for place in found {
            starts.formUnion(max(0, place - Self.reach)...place)
        }
        let compiled = regex()
        var matches: [Regex<Output>.Match] = []
        var end = normalized.startIndex
        for place in starts.sorted() where wordStarts[place] >= end {
            guard let match = normalized[wordStarts[place]...].prefixMatch(of: compiled) else { continue }
            matches.append(match)
            end = match.range.upperBound
        }
        return matches
    }

    /// How many words a match can hold before its trigger word: "entre
    /// vinte e um e vinte e cinco de outubro" holds nine.
    private static let reach = 12

    /// The regex's matches, or none without running it when the text lacks
    /// every one of the characters a match needs: the hyphen or the dot of
    /// "25-12-2027" and "25.12.2027".
    func matches<Output>(
        of regex: @autoclosure () -> Regex<Output>, whenContainsAny characters: Set<Character>
    )
        -> [Regex<Output>.Match]
    {
        guard !skipsRules || (hasDigit && normalized.contains(where: characters.contains)) else { return [] }
        return normalized.matches(of: regex())
    }

    /// The regex's matches, or none without running it when the text lacks a
    /// character every match needs: the slash of "25/09".
    func matches<Output>(of regex: @autoclosure () -> Regex<Output>, whenContains character: Character)
        -> [Regex<Output>.Match]
    {
        guard !skipsRules || (hasDigit && normalized.contains(character)) else { return [] }
        return normalized.matches(of: regex())
    }

    /// Punctuation that becomes a space can join its neighbour into one
    /// character: a line break keeps a spacing mark apart ("\n\u{093E}"), a
    /// space does not. Such a neighbour becomes a space too, so every position
    /// still maps to the writer's text.
    private static func separate(_ characters: inout [Character]) {
        for _ in 0..<4 {
            var changed = false
            for index in characters.indices.dropFirst()
            where String([characters[index - 1], characters[index]]).count != 2 {
                let side = characters[index].isASCII ? index - 1 : index
                characters[side] = " "
                changed = true
            }
            if !changed { return }
        }
        if String(characters).count != characters.count {
            characters = characters.map { $0.isASCII ? $0 : " " }
        }
    }

    /// One character as the rules read it. ASCII, nearly all of a note, takes
    /// a table lookup; anything else goes through Foundation's folding.
    private static func normalized(_ character: Character) -> Character {
        if let ascii = character.asciiValue, character.isASCII {
            switch ascii {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"): return Character(Unicode.Scalar(ascii + 32))
            case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "0")...UInt8(ascii: "9"):
                return character
            case UInt8(ascii: "/"), UInt8(ascii: ":"), UInt8(ascii: "-"): return character
            default: return " "
            }
        }
        let folded = String(character).folding(
            options: [.diacriticInsensitive, .caseInsensitive], locale: foldingLocale)
        guard folded.count == 1, let simple = folded.first else {
            // A mark that folds to nothing, or to more than one character,
            // would merge with what came before and cost a position.
            return character.isLetter || character.isNumber ? character : " "
        }
        // A mark on its own would merge with the character before it and cost
        // a position, breaking the one-for-one promise.
        if simple.unicodeScalars.allSatisfy(\.properties.isGraphemeExtend) { return " " }
        if "–—".contains(simple) { return "-" }
        // Ordinal indicators read as the letter they stand for: "1º", "6ª".
        if simple == "º" || simple == "°" { return "o" }
        if simple == "ª" { return "a" }
        return simple.isLetter || simple.isNumber || "/:-".contains(simple) ? simple : " "
    }

    private static let foldingLocale = Locale(identifier: "pt_BR")

    /// The same position in the original text. Normalization keeps one
    /// character for each character, so the two strings are walked in step;
    /// the walk resumes where the last one stopped, so mapping every result
    /// of a parse in text order costs one pass instead of one per result.
    func originalRange(_ range: Range<String.Index>) -> Range<String.Index> {
        let lower = originalIndex(for: range.lowerBound)
        return lower..<originalIndex(for: range.upperBound)
    }

    private func originalIndex(for index: String.Index) -> String.Index {
        // Back up when the position is behind: a result maps its main range
        // and then the same spans again, a few characters back.
        while cursor.normalized > index {
            cursor.normalized = normalized.index(before: cursor.normalized)
            cursor.original = original.index(before: cursor.original)
        }
        while cursor.normalized < index {
            cursor.normalized = normalized.index(after: cursor.normalized)
            cursor.original = original.index(after: cursor.original)
        }
        return cursor.original
    }

    /// Where the last mapping to the original text stopped.
    private final class Cursor {
        var normalized: String.Index
        var original: String.Index

        init(normalized: String.Index, original: String.Index) {
            self.normalized = normalized
            self.original = original
        }
    }

    private let cursor: Cursor

    func length(of range: Range<String.Index>) -> Int {
        normalized.distance(from: range.lowerBound, to: range.upperBound)
    }

    /// Every word, in text order, with where it is.
    func wordSpans() -> [Range<String.Index>] {
        var spans: [Range<String.Index>] = []
        var index = normalized.startIndex
        while index < normalized.endIndex {
            guard Self.isWordCharacter(normalized[index]) else {
                index = normalized.index(after: index)
                continue
            }
            var end = index
            while end < normalized.endIndex, Self.isWordCharacter(normalized[end]) {
                end = normalized.index(after: end)
            }
            spans.append(index..<end)
            index = end
        }
        return spans
    }

    /// Where the phrase sits when it starts at this position and ends on a
    /// word boundary: "a noite" does not match inside "a noitinha".
    func phrase(_ phrase: String, at start: String.Index) -> Range<String.Index>? {
        var index = start
        for character in phrase {
            guard index < normalized.endIndex, normalized[index] == character else { return nil }
            index = normalized.index(after: index)
        }
        guard index == normalized.endIndex || !Self.isWordCharacter(normalized[index]) else { return nil }
        return start..<index
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

    /// Only spaces and prepositions between the two ranges, in one sentence:
    /// "amanhã às 9", "sexta à noite", "hoje, no almoço".
    func onlyConnectors(between first: Range<String.Index>, and second: Range<String.Index>) -> Bool {
        let (left, right) = first.lowerBound <= second.lowerBound ? (first, second) : (second, first)
        guard left.upperBound <= right.lowerBound else { return true }
        let gap = left.upperBound..<right.lowerBound
        return !hasSentenceBreak(in: gap) && everyWord(in: gap) { Self.connectors.contains(String($0)) }
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
        guard first.upperBound <= second.lowerBound,
            let opening = rangeOpening(of: first, bareStart: bareStart),
            closesRange(opening, from: first, to: second) == true
        else { return nil }
        return opening.start
    }

    /// How a range that starts at `first` opens: its opening word, if any,
    /// and where the range starts. `nil` when nothing can open one there.
    /// It depends only on `first`, so a rule that pairs `first` with many
    /// ends works it out once.
    func rangeOpening(of first: Range<String.Index>, bareStart: Bool) -> RangeOpening? {
        if let word = words(after: first.lowerBound, count: 1).first, Self.rangeOpenings.contains(word) {
            return RangeOpening(start: first.lowerBound, entre: word == "entre")
        }
        if let before = wordRange(before: first.lowerBound),
            Self.rangeOpenings.contains(String(normalized[before]))
        {
            return RangeOpening(start: before.lowerBound, entre: normalized[before] == "entre")
        }
        return bareStart ? RangeOpening(start: first.lowerBound, entre: false) : nil
    }

    struct RangeOpening {
        let start: String.Index
        /// "de segunda e quarta" is two days; "entre segunda e quarta" is a range.
        let entre: Bool

        var closings: Set<String> { entre ? TextSource.entreClosings : TextSource.rangeClosings }
    }

    /// Whether `second` closes the range `opening` opened at `first`. `nil`
    /// when the gap holds a word no range allows: every later end has that
    /// word in its gap too, so a caller walking ends in text order can stop.
    ///
    /// Words `skipping` accepts sit in the gap without opening or closing
    /// anything: the time in "de segunda às 14h até sexta".
    func closesRange(
        _ opening: RangeOpening, from first: Range<String.Index>, to second: Range<String.Index>,
        skipping: (Substring) -> Bool = { _ in false }
    ) -> Bool? {
        let gap = first.upperBound..<second.lowerBound
        let closings = opening.closings
        var closed = false
        guard
            everyWord(
                in: gap,
                { word in
                    if skipping(word) { return true }
                    let word = String(word)
                    if closings.contains(word) { closed = true }
                    return closings.contains(word) || Self.articles.contains(word)
                })
        else { return nil }
        if closed { return true }
        if hasNoWord(in: gap), normalized[gap].contains("-") { return true }
        return words(after: second.lowerBound, count: 1).first.map(closings.contains) ?? false
    }

    private static let rangeClosings: Set<String> = ["a", "as", "ao", "ate"]
    private static let entreClosings: Set<String> = ["e"]

    /// Whether a phrase can end at the position: the text ends, a
    /// punctuation mark follows, or the next word is a connector. In "sexta,
    /// 25 às 10h" and "sexta, 25, reunião" the 25 is a day; in "sexta 25
    /// pessoas" it counts something.
    func endsPhrase(at index: String.Index) -> Bool {
        guard let next = words(after: index, count: 1).first, !Self.connectors.contains(next) else {
            return true
        }
        let position = originalRange(index..<index).lowerBound
        return position < original.endIndex
            && (original[position].isNewline || ",.;:!?".contains(original[position]))
    }

    /// Whether a phrase can start at the position: the text starts there, a
    /// punctuation mark comes before, or the word before is a connector. In
    /// "sala 12 às 15h" the 12 follows a noun and names the room.
    func startsPhrase(at index: String.Index) -> Bool {
        guard let before = wordRange(before: index), !Self.connectors.contains(String(normalized[before]))
        else {
            return true
        }
        return original[originalRange(before.upperBound..<index)].contains {
            $0.isNewline || ",.;:!?()".contains($0)
        }
    }

    /// The range as the writer typed it.
    func originalText(_ range: Range<String.Index>) -> Substring {
        original[originalRange(range)]
    }

    /// Whether the character at the position was written with a grave
    /// accent: "às" and "à", never an article.
    func hasGrave(at index: String.Index) -> Bool {
        let position = originalRange(index..<index).lowerBound
        return position < original.endIndex
            && original[position].unicodeScalars.contains {
                "àÀ".unicodeScalars.contains($0) || $0 == "\u{300}"
            }
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
