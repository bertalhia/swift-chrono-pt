import Foundation

/// A piece of text found by a rule, with its position in the normalized text.
struct Piece<Value: Sendable>: Sendable {
    let range: Range<String.Index>
    let value: Value
    /// Breaks a tie when two rules find the same span: the higher one wins.
    /// Without it the survivor would depend on the sort being stable, which
    /// Swift does not promise, and the same text could give two answers.
    var priority: Int = 0

    /// Drops overlapping pieces: the one that starts first stays and, on a
    /// tie, the longest. "Depois de amanhã" beats "amanhã"; "de manhã cedo"
    /// beats "de manhã". The result is in text order.
    static func nonOverlapping(_ pieces: [Self], in source: TextSource) -> [Self] {
        let sorted = pieces.sorted { lhs, rhs in
            if lhs.range.lowerBound != rhs.range.lowerBound {
                return lhs.range.lowerBound < rhs.range.lowerBound
            }
            let (left, right) = (source.length(of: lhs.range), source.length(of: rhs.range))
            if left != right { return left > right }
            return lhs.priority > rhs.priority
        }
        // Sorted by start, a piece overlaps a kept one exactly when it starts
        // before the furthest kept end.
        var kept: [Self] = []
        var end = source.normalized.startIndex
        for piece in sorted where kept.isEmpty || piece.range.lowerBound >= end {
            kept.append(piece)
            end = max(end, piece.range.upperBound)
        }
        return kept
    }
}
