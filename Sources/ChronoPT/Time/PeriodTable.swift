import Foundation

/// Parts of the day and moments, with the hour a person would expect.
extension TimeRules {
    struct Period {
        let phrases: [String]
        let hour: Int
        var minute = 0
        var needsDay = false
    }

    /// Lowercase, without accents. The hour is the one a person would expect
    /// on the reminder: lunch at noon, dinner at 19:00, "de madrugada" at 5:00.
    static let table: [Period] = [
        Period(phrases: ["depois do almoco", "dps do almoco", "apos o almoco"], hour: 14),
        Period(phrases: ["antes do almoco"], hour: 11),
        Period(
            phrases: [
                "na hora do almoco", "no horario do almoco", "no almoco", "ao almoco", "a hora do almoco",
                "a hora de almoco", "na hora de almoco",
            ], hour: 12),
        Period(
            phrases: [
                "depois da janta", "depois do jantar", "dps da janta", "dps do jantar", "apos a janta",
                "apos o jantar",
            ], hour: 21),
        Period(phrases: ["antes da janta", "antes do jantar"], hour: 18),
        Period(
            phrases: [
                "na hora da janta", "na hora do jantar", "na janta", "no jantar", "ao jantar",
                "a hora do jantar", "a hora de jantar", "na hora de jantar",
            ], hour: 19),
        Period(
            phrases: [
                "no cafe da manha", "na hora do cafe", "ao cafe da manha", "ao pequeno-almoco",
                "no pequeno-almoco", "ao pequeno almoco",
            ], hour: 8),
        Period(phrases: ["no lanche da tarde", "no cafe da tarde", "na hora do lanche"], hour: 16),
        Period(phrases: ["antes de dormir", "na hora de dormir"], hour: 22),
        Period(phrases: ["ao acordar", "quando acordar", "quando eu acordar", "assim que acordar"], hour: 7),
        Period(
            phrases: [
                "depois do trabalho", "depois do expediente", "dps do trabalho", "dps do expediente",
                "no fim do expediente", "ate o fim do expediente", "ate o final do expediente",
                "saindo do trabalho",
            ], hour: 18),
        Period(phrases: ["de madrugada", "na madrugada", "pela madrugada", "de madruga"], hour: 5),
        Period(
            phrases: [
                "de manha cedo", "de manha bem cedo", "de manha bem cedinho", "bem cedo de manha",
                "de manhazinha", "logo cedo", "bem cedo", "cedinho",
            ], hour: 7),
        Period(phrases: ["cedo"], hour: 7, needsDay: true),
        Period(phrases: ["no meio da manha"], hour: 10),
        Period(
            phrases: ["no fim da manha", "no final da manha", "ate o fim da manha", "ate o final da manha"],
            hour: 11),
        Period(
            phrases: [
                "de manha", "pela manha", "na parte da manha", "esta manha", "essa manha", "nesta manha",
                "nessa manha",
            ], hour: 9),
        Period(phrases: ["no comeco da tarde", "no inicio da tarde", "no comecinho da tarde"], hour: 13),
        Period(phrases: ["no meio da tarde"], hour: 15),
        Period(
            phrases: [
                "a tarde", "de tarde", "pela tarde", "na parte da tarde", "esta tarde", "essa tarde",
                "nesta tarde", "nessa tarde",
            ], hour: 15),
        Period(
            phrases: [
                "no fim da tarde", "no final da tarde", "no fim de tarde", "ao fim da tarde",
                "ao final da tarde", "ate o fim da tarde", "ate o final da tarde", "a tardinha",
                "de tardinha", "de tardezinha",
            ], hour: 18),
        Period(
            phrases: [
                "no fim do dia", "no final do dia", "ao fim do dia", "ao final do dia", "ate o fim do dia",
                "no finalzinho do dia",
                "ate o final do dia",
            ], hour: 18),
        Period(phrases: ["a noitinha", "de noitinha", "no comeco da noite", "no inicio da noite"], hour: 19),
        Period(
            phrases: [
                "a noite", "de noite", "pela noite", "na parte da noite", "esta noite", "essa noite",
                "nesta noite", "nessa noite",
            ], hour: 19),
        Period(phrases: ["na boquinha da noite", "de boquinha da noite"], hour: 18, minute: 30),
        Period(phrases: ["tarde da noite"], hour: 23),
    ]

    /// Whole parts of the day, and the whole day. The longer phrase wins
    /// over a part of the day inside it: "a tarde toda" over "a tarde".
    static let wholeParts: [(phrases: [String], value: Value)] = [
        (
            [
                "o dia todo", "o dia inteiro", "dia inteiro", "o dia todinho", "durante o dia todo",
                "durante todo o dia", "o dia inteirinho",
            ], .allDay
        ),
        (
            ["a manha toda", "a manha inteira", "toda a manha", "a manha todinha", "durante toda a manha"],
            .span(from: 6, until: 12)
        ),
        (
            ["a tarde toda", "a tarde inteira", "toda a tarde", "a tarde todinha", "durante toda a tarde"],
            .span(from: 12, until: 18)
        ),
        (
            ["a noite toda", "a noite inteira", "toda a noite", "a noite todinha", "durante toda a noite"],
            .span(from: 18, until: 24)
        ),
        (["a madrugada toda", "a madrugada inteira", "toda a madrugada"], .span(from: 0, until: 6)),
    ]

    /// Every phrase by its first word, so a parse walks the text once instead
    /// of searching it for each of a hundred phrases.
    static let phrasesByFirstWord: [String: [(phrase: String, value: Value)]] = {
        let periods = table.map { period in
            (
                period.phrases,
                Value.period(hour: period.hour, minute: period.minute, needsDay: period.needsDay)
            )
        }
        var index: [String: [(phrase: String, value: Value)]] = [:]
        for (phrases, value) in periods + wholeParts {
            for phrase in phrases {
                let first = String(phrase.prefix { $0.isLetter || $0.isNumber })
                index[first, default: []].append((phrase, value))
            }
        }
        return index
    }()

    /// An app's moments, from `ChronoPT.Options.moments`, indexed like the
    /// table: "No Treino" reads as "no treino".
    static func index(of moments: [String: Int]) -> [String: [(phrase: String, value: Value)]] {
        var index: [String: [(phrase: String, value: Value)]] = [:]
        // In key order, so two keys that read the same ("No Treino", "no
        // treino") give the same answer on every run: the first one wins.
        for (text, hour) in moments.sorted(by: { $0.key < $1.key }) where (0...23).contains(hour) {
            let phrase = TextSource(text).normalized.split(separator: " ").joined(separator: " ")
            let first = String(phrase.prefix { $0.isLetter || $0.isNumber })
            guard !first.isEmpty, !(index[first]?.contains { $0.phrase == phrase } ?? false) else { continue }
            index[first, default: []].append((phrase, .period(hour: hour, minute: 0, needsDay: false)))
        }
        return index
    }

    /// The phrases of the index in the text. A higher priority wins a tie with
    /// the same phrase from another index.
    static func periods(
        in source: TextSource,
        index: [String: [(phrase: String, value: Value)]] = phrasesByFirstWord,
        priority: Int = 0
    ) -> [Piece<Value>] {
        guard !index.isEmpty else { return [] }
        return source.wordSpans().flatMap { word -> [Piece<Value>] in
            guard let entries = index[String(source.normalized[word])] else { return [] }
            return entries.compactMap { entry in
                source.phrase(entry.phrase, at: word.lowerBound).map {
                    Piece(range: $0, value: entry.value, priority: priority)
                }
            }
        }
    }
}
