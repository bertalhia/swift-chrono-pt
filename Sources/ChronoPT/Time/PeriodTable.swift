import Foundation

/// Parts of the day and moments, with the hour a person would expect.
extension TimeRules {
    struct Period {
        let phrases: [String]
        let hour: Int
        var needsDay = false
    }

    /// Lowercase, without accents. The hour is the one a person would expect
    /// on the reminder: lunch at noon, dinner at 19:00, "de madrugada" at 5:00.
    static let table: [Period] = [
        Period(phrases: ["depois do almoco", "dps do almoco", "apos o almoco"], hour: 14),
        Period(phrases: ["antes do almoco"], hour: 11),
        Period(phrases: ["na hora do almoco", "no horario do almoco", "no almoco", "ao almoco", "a hora do almoco", "a hora de almoco", "na hora de almoco"], hour: 12),
        Period(phrases: ["depois da janta", "depois do jantar", "dps da janta", "dps do jantar", "apos a janta", "apos o jantar"], hour: 21),
        Period(phrases: ["antes da janta", "antes do jantar"], hour: 18),
        Period(phrases: ["na hora da janta", "na hora do jantar", "na janta", "no jantar", "ao jantar", "a hora do jantar", "a hora de jantar", "na hora de jantar"], hour: 19),
        Period(phrases: ["no cafe da manha", "na hora do cafe", "ao cafe da manha", "ao pequeno-almoco", "no pequeno-almoco", "ao pequeno almoco"], hour: 8),
        Period(phrases: ["no lanche da tarde", "no cafe da tarde", "na hora do lanche"], hour: 16),
        Period(phrases: ["antes de dormir", "na hora de dormir"], hour: 22),
        Period(phrases: ["ao acordar", "quando acordar", "quando eu acordar", "assim que acordar"], hour: 7),
        Period(phrases: ["depois do trabalho", "depois do expediente", "dps do trabalho", "dps do expediente", "no fim do expediente", "ate o fim do expediente", "ate o final do expediente", "saindo do trabalho"], hour: 18),
        Period(phrases: ["de madrugada", "na madrugada", "pela madrugada"], hour: 5),
        Period(phrases: ["de manha cedo", "de manha bem cedo", "de manha bem cedinho", "bem cedo de manha", "de manhazinha", "logo cedo", "bem cedo", "cedinho"], hour: 7),
        Period(phrases: ["cedo"], hour: 7, needsDay: true),
        Period(phrases: ["no meio da manha"], hour: 10),
        Period(phrases: ["no fim da manha", "no final da manha", "ate o fim da manha", "ate o final da manha"], hour: 11),
        Period(phrases: ["de manha", "pela manha", "na parte da manha", "esta manha", "essa manha", "nesta manha", "nessa manha"], hour: 9),
        Period(phrases: ["no comeco da tarde", "no inicio da tarde"], hour: 13),
        Period(phrases: ["no meio da tarde"], hour: 15),
        Period(phrases: ["a tarde", "de tarde", "pela tarde", "na parte da tarde", "esta tarde", "essa tarde", "nesta tarde", "nessa tarde"], hour: 15),
        Period(phrases: ["no fim da tarde", "no final da tarde", "no fim de tarde", "ao fim da tarde", "ao final da tarde", "ate o fim da tarde", "ate o final da tarde", "a tardinha", "de tardinha"], hour: 18),
        Period(phrases: ["no fim do dia", "no final do dia", "ao fim do dia", "ao final do dia", "ate o fim do dia", "ate o final do dia"], hour: 18),
        Period(phrases: ["a noitinha", "de noitinha", "no comeco da noite", "no inicio da noite"], hour: 19),
        Period(phrases: ["a noite", "de noite", "pela noite", "na parte da noite", "esta noite", "essa noite", "nesta noite", "nessa noite"], hour: 19),
        Period(phrases: ["tarde da noite"], hour: 23)
    ]

    static func periods(in source: TextSource) -> [Piece<Value>] {
        table.flatMap { period in
            period.phrases.flatMap { phrase in
                source.wordRanges(of: phrase).map {
                    Piece(range: $0, value: .period(hour: period.hour, needsDay: period.needsDay))
                }
            }
        }
    }
}
