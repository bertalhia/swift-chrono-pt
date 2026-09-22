import Foundation

/// A piece of text found by a rule, with its position in the normalized text.
struct Piece<Value: Sendable>: Sendable {
    let range: Range<String.Index>
    let value: Value

    /// Drops overlapping pieces: the one that starts first stays and, on a
    /// tie, the longest. "Depois de amanhã" beats "amanhã"; "de manhã cedo"
    /// beats "de manhã". The result is in text order.
    static func nonOverlapping(_ pieces: [Self], in source: TextSource) -> [Self] {
        let sorted = pieces.sorted { lhs, rhs in
            if lhs.range.lowerBound != rhs.range.lowerBound { return lhs.range.lowerBound < rhs.range.lowerBound }
            return source.length(of: lhs.range) > source.length(of: rhs.range)
        }
        var kept: [Self] = []
        for piece in sorted where !kept.contains(where: { $0.range.overlaps(piece.range) }) {
            kept.append(piece)
        }
        return kept
    }
}
