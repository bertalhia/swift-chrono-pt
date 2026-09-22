import Foundation

extension ChronoPT {
    /// The text without the dates: "comprar pão amanhã no almoço" gives
    /// "comprar pão".
    ///
    /// Every expression `parse` finds comes out, along with the word that
    /// introduced it ("de amanhã", "para sexta") and the punctuation it leaves
    /// behind, which is what a notes app needs to keep as the title.
    public static func strippingDates(
        from text: String,
        reference: Date = .now,
        calendar: Calendar = .current,
        options: Options = Options()
    ) -> String {
        let spans = parse(text, reference: reference, calendar: calendar, options: options).flatMap(\.ranges)
        return text.removing(spans)
    }
}

extension String {
    /// This text without those spans, with the word that introduced each one
    /// and any punctuation left dangling.
    func removing(_ spans: [Range<String.Index>]) -> String {
        var cuts: [Range<String.Index>] = []
        for span in spans.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            var start = span.lowerBound
            while let word = wordRange(before: start), Self.leadIns.contains(folded(self[word])) {
                start = word.lowerBound
            }
            if let last = cuts.last, last.upperBound >= start {
                cuts[cuts.count - 1] = last.lowerBound..<Swift.max(last.upperBound, span.upperBound)
            } else {
                cuts.append(start..<span.upperBound)
            }
        }

        var kept = ""
        var index = startIndex
        for cut in cuts {
            kept += self[index..<cut.lowerBound]
            index = cut.upperBound
        }
        kept += self[index...]
        return kept.tidied()
    }

    /// Words that only introduce a date and have nothing left to say once it
    /// is gone: "almoço de amanhã" keeps "almoço".
    private static let leadIns: Set<String> = [
        "de", "do", "da", "em", "no", "na", "nos", "nas", "para", "pra", "pro", "ate", "a", "ao", "as", "aos",
        "o", "os",
    ]

    private func folded(_ text: Substring) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
    }

    private func wordRange(before index: String.Index) -> Range<String.Index>? {
        var end = index
        while end > startIndex, !self[self.index(before: end)].isLetter,
            !self[self.index(before: end)].isNumber
        {
            end = self.index(before: end)
        }
        var start = end
        while start > startIndex,
            self[self.index(before: start)].isLetter || self[self.index(before: start)].isNumber
        {
            start = self.index(before: start)
        }
        return start < end ? start..<end : nil
    }

    /// Spaces and punctuation the cut left behind, in one pass: a run of
    /// spaces becomes one, no space stays before punctuation, a comma before
    /// another mark goes ("pão,."), a dash after a dash goes ("— —"), and so
    /// do empty brackets.
    private func tidied() -> String {
        var text = ""
        text.reserveCapacity(utf8.count)
        func trimSpaces() {
            while let last = text.last, last.isWhitespace { text.removeLast() }
        }
        for character in self {
            switch character {
            case " ", "\t":
                if let last = text.last, last != " " { text.append(" ") }
            case ",", ".", ";", ":", "!", "?":
                trimSpaces()
                if let last = text.last, ",;:".contains(last) { text.removeLast() }
                text.append(character)
            case "–", "—", "-":
                if text.last(where: { !$0.isWhitespace }).map({ "–—-".contains($0) }) == true,
                    text.last?.isWhitespace == true
                {
                    continue
                }
                text.append(character)
            case ")", "]":
                let opening: Character = character == ")" ? "(" : "["
                if text.last(where: { !$0.isWhitespace }) == opening {
                    trimSpaces()
                    text.removeLast()
                    continue
                }
                text.append(character)
            default:
                text.append(character)
            }
        }
        return text.trimmingCharacters(
            in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:-–—")))
    }
}
