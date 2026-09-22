import Foundation

/// The regex rules, word tables and small helpers the day rules match with.
extension DayRules {
    static var relativeDay: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b((?:depois|dps) de (?:amanha|amn)|amanha|amn|hoje|hj|antes de ontem|anteontem|ontem)\b/#.wordBoundaryKind(.simple)
        }
    }

    // "daqui 2 dias", "daqui a três semanas", "em 3 dias", "dentro de um mês"
    // "há 2 dias", "faz uma semana"
    static var agoAmount: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:ha|faz) (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (dias?|semanas?|mes|meses)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "3 dias atrás"
    static var amountAgo: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (dias?|semanas?|mes|meses) atras\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "sexta passada", "na última sexta", "segunda-feira passada"
    static var lastWeekday: Regex<(Substring, Substring?, Substring?)> {
        RegexCache.regex {
            #/\b(?:(?:na|no|o|a) )?(?:(?:ultima|ultimo) (segunda|terca|quarta|quinta|sexta|sabado|domingo|seg|qua|qui|sex|sab|dom)(?:-feira| feira)?|(segunda|terca|quarta|quinta|sexta|sabado|domingo|seg|qua|qui|sex|sab|dom)(?:-feira| feira)? (?:passada|passado))\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "a cada 15 dias", "cada 2 meses"
    static var everyInterval: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:a )?cada (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (horas?|minutos?|min|dias?|semanas?|mes|meses)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "de 2 em 2 semanas"
    static var fromToInterval: Regex<(Substring, Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\bde (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) em (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (horas?|minutos?|min|dias?|semanas?|mes|meses)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "toda semana", "todo mês", "semanalmente", "mensalmente"
    static var everyUnit: Regex<Substring> {
        RegexCache.regex {
            #/\b(?:toda(?:s as)? semanas?|todo(?:s os)? (?:mes|meses)|semanalmente|mensalmente|de hora em hora|a cada hora)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "todo dia", "todos os dias", "diariamente"
    static var everyDay: Regex<Substring> {
        RegexCache.regex {
            #/\b(?:todo dia|todos os dias|todo santo dia|diariamente)\b/#.wordBoundaryKind(.simple)
        }
    }

    // "dia 10 de cada mês", "no dia 5 de todo mês"
    static var monthlyDay: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:no |em )?dia (\d{1,2}|primeiro|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)\b de (?:cada|todo o|todo) mes\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "todo dia 5", "todo mês no dia 10"
    static var everyMonth: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:todo mes(?: no)? dia|todos os dias|todo dia) (\d{1,2}|primeiro|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)\b(?!/)/#
                .wordBoundaryKind(.simple)
        }
    }

    // "toda terça", "todas as sextas", "às segundas e quartas", "nas terças e quintas"
    static var everyWeekday: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(toda|todo|todas as|todos os|as|aos|nas|nos) ((?:(?:segunda|terca|quarta|quinta|sexta)s?(?:-feiras?)?|sabados?|domingos?)(?:(?:,|, e| e) (?:(?:segunda|terca|quarta|quinta|sexta)s?(?:-feiras?)?|sabados?|domingos?))*)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    static var inAmount: Regex<(Substring, Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(daqui a|daqui|em|dentro de) (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (dias?|semanas?|mes|meses)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "na sexta", "segunda-feira", "sexta que vem", "quarta da semana que vem"
    static var weekday: Regex<(Substring, Substring?, Substring, Substring?, Substring?)> {
        RegexCache.regex {
            #/\b(?:(na|no|nesta|neste|esta|este|essa|esse|nessa|nesse|proxima|proximo|prox|ate|pra|para|pro) )?(segunda|terca|quarta|quinta|sexta|sabado|domingo|seg|qua|qui|sex|sab|dom)(-feira| feira)?( que vem| da semana que vem| da proxima semana)?\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "25/09", "dia 25/09/2026", "5/1/27"
    static var numericDate: Regex<(Substring, Substring, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(?:dia )?(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?\b/#.wordBoundaryKind(.simple)
        }
    }

    // "2026-10-15"
    static var isoDate: Regex<(Substring, Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(\d{4})-(\d{1,2})-(\d{1,2})\b/#.wordBoundaryKind(.simple)
        }
    }

    // "15 de outubro", "dia 1º de maio", "vinte e três de outubro", "3 out 2027"
    static var monthName: Regex<(Substring, Substring, Substring?, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(?:dia )?(\d{1,2}|primeiro|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)(?:o|º)? (de )?(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro|jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\b(?: (?:de )?(\d{4})\b)?/#
                .wordBoundaryKind(.simple)
        }
    }

    // "de 10 a 15 de outubro", "entre 3 e 5 de maio": the first day takes the month of the second
    static var dayRangeInMonth: Regex<(Substring, Substring, Substring, Substring, Substring, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(de|entre) (\d{1,2}|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)(?:o|º)? (a|ao|ate|e) (\d{1,2}|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)(?:o|º)? de (janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro|jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\b(?: (?:de )?(\d{4})\b)?/#
                .wordBoundaryKind(.simple)
        }
    }

    // "dia 30", "até dia 5", "dia primeiro", "dia quinze"; "dia 25/09" is left to `numericDate`.
    static var dayOfMonth: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\bdia (\d{1,2}|primeiro|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)\b(?!/)/#.wordBoundaryKind(.simple)
        }
    }

    static var namedPeriod: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b(esta semana que vem|essa semana que vem|esta semana|essa semana|nesta semana|nessa semana|semana que vem|proxima semana|prox semana|fim de semana que vem|final de semana que vem|proximo fim de semana|proximo final de semana|fim de semana passado|final de semana passado|fim de semana|final de semana|fds|este mes|esse mes|neste mes|nesse mes|(?:comeco|inicio) do (?:mes que vem|proximo mes)|mes que vem|proximo mes|prox mes|fim do mes que vem|final do mes que vem|fim do mes|final do mes|ano que vem|proximo ano|prox ano|semana passada|mes passado|ano passado)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "no natal", "véspera de natal", "dia de finados", "na sexta-feira santa"
    static var holidayName: Regex<(Substring, Substring?, Substring)> {
        RegexCache.regex {
            #/\b(?:(no proximo|na proxima|no|na|ate o|ate a|ate|neste|nesta|nesse|nessa|este|esta|esse|essa|feriado de|feriado do|feriado da|dia de|dia do|dia da) )?(vespera de natal|natal|reveillon|virada do ano|ano novo|ano-novo|tiradentes|dia do trabalhador|dia do trabalho|independencia|dia das criancas|nossa senhora aparecida|finados|proclamacao da republica|consciencia negra|dia dos namorados|carnaval|quarta-feira de cinzas|quarta de cinzas|sexta-feira santa|sexta-feira da paixao|sexta santa|pascoa|corpus christi|dia das maes|dia dos pais)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    struct HolidayName {
        let holiday: Holiday
        var needsPreposition = false
    }

    static let holidays: [String: HolidayName] = [
        "natal": HolidayName(holiday: .fixed(month: 12, day: 25), needsPreposition: true),
        "vespera de natal": HolidayName(holiday: .fixed(month: 12, day: 24)),
        "reveillon": HolidayName(holiday: .fixed(month: 12, day: 31), needsPreposition: true),
        "virada do ano": HolidayName(holiday: .fixed(month: 12, day: 31)),
        "ano novo": HolidayName(holiday: .fixed(month: 1, day: 1), needsPreposition: true),
        "ano-novo": HolidayName(holiday: .fixed(month: 1, day: 1), needsPreposition: true),
        "tiradentes": HolidayName(holiday: .fixed(month: 4, day: 21), needsPreposition: true),
        "dia do trabalho": HolidayName(holiday: .fixed(month: 5, day: 1)),
        "dia do trabalhador": HolidayName(holiday: .fixed(month: 5, day: 1)),
        "dia dos namorados": HolidayName(holiday: .fixed(month: 6, day: 12)),
        "independencia": HolidayName(holiday: .fixed(month: 9, day: 7), needsPreposition: true),
        "dia das criancas": HolidayName(holiday: .fixed(month: 10, day: 12)),
        "nossa senhora aparecida": HolidayName(holiday: .fixed(month: 10, day: 12), needsPreposition: true),
        "finados": HolidayName(holiday: .fixed(month: 11, day: 2)),
        "proclamacao da republica": HolidayName(holiday: .fixed(month: 11, day: 15)),
        "consciencia negra": HolidayName(holiday: .fixed(month: 11, day: 20), needsPreposition: true),
        "carnaval": HolidayName(holiday: .easter(offset: -50, lastDay: -47), needsPreposition: true),
        "quarta-feira de cinzas": HolidayName(holiday: .easter(offset: -46)),
        "quarta de cinzas": HolidayName(holiday: .easter(offset: -46)),
        "sexta-feira santa": HolidayName(holiday: .easter(offset: -2)),
        "sexta-feira da paixao": HolidayName(holiday: .easter(offset: -2)),
        "sexta santa": HolidayName(holiday: .easter(offset: -2)),
        "pascoa": HolidayName(holiday: .easter(offset: 0), needsPreposition: true),
        "corpus christi": HolidayName(holiday: .easter(offset: 60)),
        "dia das maes": HolidayName(holiday: .secondSunday(month: 5)),
        "dia dos pais": HolidayName(holiday: .secondSunday(month: 8))
    ]

    /// Days, weeks or months, ready for `Calendar.date(byAdding:to:)`.
    static func components(_ count: Int, unit: some StringProtocol) -> DateComponents {
        if unit.hasPrefix("hora") { DateComponents(hour: count) }
        else if unit.hasPrefix("min") { DateComponents(minute: count) }
        else if unit.hasPrefix("dia") { DateComponents(day: count) }
        else if unit.hasPrefix("semana") { DateComponents(weekOfYear: count) }
        else { DateComponents(month: count) }
    }

    static func amount(_ count: Int, unit: Substring) -> Value {
        unit.hasPrefix("dia") ? .days(count) : unit.hasPrefix("semana") ? .weeks(count) : .months(count)
    }

    /// `Calendar` weekday numbers, from 1, as `Locale.Weekday`.
    static let localeWeekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    static let relativeDays = [
        "ontem": -1, "anteontem": -2, "antes de ontem": -2,
        "hoje": 0, "hj": 0, "amanha": 1, "amn": 1,
        "depois de amanha": 2, "depois de amn": 2, "dps de amanha": 2, "dps de amn": 2
    ]

    /// Abbreviations need the same hint as "segunda" to "sexta", even "sáb" and
    /// "dom" ("o dom de ensinar"). "ter" is left out: it is the verb "to have"
    /// ("para ter certeza", "vou ter às 15 uma reunião"), and no hint tells
    /// the two apart.
    static let weekdays = [
        "domingo": 1, "segunda": 2, "terca": 3, "quarta": 4, "quinta": 5, "sexta": 6, "sabado": 7,
        "dom": 1, "seg": 2, "qua": 4, "qui": 5, "sex": 6, "sab": 7
    ]

    /// Weekdays with no other meaning, which count on their own.
    static let weekdaysAlone: Set<String> = ["sabado", "domingo"]

    static let months = [
        "janeiro": 1, "jan": 1, "fevereiro": 2, "fev": 2, "marco": 3, "mar": 3, "abril": 4, "abr": 4,
        "maio": 5, "mai": 5, "junho": 6, "jun": 6, "julho": 7, "jul": 7, "agosto": 8, "ago": 8,
        "setembro": 9, "set": 9, "outubro": 10, "out": 10, "novembro": 11, "nov": 11, "dezembro": 12, "dez": 12
    ]

    static func dayNumber(_ text: Substring) -> Int? {
        text == "primeiro" ? 1 : SpokenNumber.value(text)
    }

    /// A two-digit year is in this century: "27" is 2027.
    static func year(_ text: String) -> Int? {
        guard let value = Int(text) else { return nil }
        return text.count == 2 ? 2000 + value : value
    }
}
