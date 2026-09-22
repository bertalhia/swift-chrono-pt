import Foundation

/// The clock rules and the regexes they match with.
extension TimeRules {
    static func clocks(in source: TextSource) -> [Piece<Value>] {
        source.matches(of: clock, whenAny: hourWords, orDigit: true).compactMap { match in
            let (_, prefix, hourText, separator, minuteText, unit, minuteWords, meridiem) = match.output
            let spoken = Int(hourText) == nil
            // A bare number is not a time: it needs "às", "h", ":" or "da tarde".
            // A spelled-out hour needs "às" or "da tarde", because "uma" is also
            // an article.
            let marked = prefix != nil || meridiem != nil || (!spoken && (separator != nil || unit != nil))
            guard marked, let base = SpokenNumber.value(hourText), (0...23).contains(base) else { return nil }
            if prefix == nil, meridiem == nil, isDuration(match.range, in: source) { return nil }
            // A word that also counts things marks a time only with "h", a
            // colon, a part of the day or the end of a phrase: "chego umas 8",
            // "umas 3h", but not "umas 8 laranjas". With "horas" it is how
            // long: "umas 2 horas".
            if let prefix, approximateWords.contains(String(prefix)) {
                let clockUnit =
                    unit.map { ["h", "hs"].contains($0.trimmingCharacters(in: .whitespaces)) } ?? false
                guard unit == nil || clockUnit, !isDuration(match.range, in: source),
                    separator != nil || clockUnit || meridiem != nil
                        || source.endsPhrase(at: match.range.upperBound)
                else { return nil }
            }

            let minute: Int
            if let minuteText {
                // `\d` matches any digit in the world; `Int` only reads ASCII.
                guard let written = Int(minuteText) else { return nil }
                minute = written
            } else if let minuteWords {
                minute = minuteWords == "meia" ? 30 : SpokenNumber.value(minuteWords) ?? 0
            } else {
                minute = 0
            }
            guard (0...59).contains(minute) else { return nil }

            if let meridiem {
                let (hour, nextDay) = clockHour(base, meridiem: meridiem)
                return Piece(
                    range: match.range,
                    value: .clock(hour: hour, minute: minute, ambiguous: false, nextDay: nextDay))
            }
            // Written "7h" or "07:00" is the 24-hour clock; spoken, "às 7"
            // doesn't say morning or evening.
            let written = separator != nil || unit?.first == "h" || hourText.hasPrefix("0")
            let ambiguous = (1...11).contains(base) && !written
            return Piece(
                range: match.range,
                value: .clock(hour: base, minute: minute, ambiguous: ambiguous, nextDay: false))
        }
    }

    /// Minutes before the hour: "quinze para as oito" is 7:45. The named hour
    /// decides morning or evening, as in "às oito".
    static func minutesToHour(in source: TextSource) -> [Piece<Value>] {
        source.matches(of: minutesTo, whenAny: towardWords).compactMap { match in
            let (_, minuteText, unit, hourText, meridiem) = match.output
            // Digits need "min": "de 3 pra 1" is a score.
            guard Int(minuteText) == nil || unit != nil,
                let minutes = SpokenNumber.value(minuteText), (1...30).contains(minutes)
            else { return nil }

            let clock: (hour: Int, ambiguous: Bool, nextDay: Bool)
            if hourText.hasPrefix("meio") {
                clock = (12, false, false)
            } else if hourText.hasPrefix("meia") {
                clock = (0, false, true)
            } else {
                guard let named = SpokenNumber.value(hourText), (1...12).contains(named) else { return nil }
                if let meridiem {
                    let (hour, nextDay) = clockHour(named, meridiem: meridiem)
                    clock = (hour, false, nextDay)
                } else {
                    clock = (named, named <= 11, false)
                }
            }
            return Piece(
                range: match.range,
                value: .clock(
                    hour: clock.hour, minute: -minutes, ambiguous: clock.ambiguous, nextDay: clock.nextDay))
        }
    }

    /// A bare hour after "de" or "entre", followed by the word that closes a
    /// range: "de 9" in "de 9 a 11h". It counts only with an end.
    static func rangeStarts(in source: TextSource) -> [Piece<Value>] {
        source.matches(of: bareRangeStart, whenAny: hourWords, orDigit: true).compactMap { match in
            // Not a number inside a date or a clock time: "25/09 às 14:00".
            let before = source.normalized[..<match.range.lowerBound].last
            guard before.map({ !"/:-0123456789".contains($0) }) ?? true,
                let hour = SpokenNumber.value(match.output.1), (0...23).contains(hour)
            else { return nil }
            let value = Value.clock(
                hour: hour, minute: 0, ambiguous: (1...11).contains(hour), nextDay: false, needsEnd: true)
            return Piece(range: match.range, value: value)
        }
    }

    /// The 24-hour clock for a spoken hour and its part of the day: "7 da
    /// noite" is 19:00, and "12 da noite" is midnight, the start of the next day.
    static func clockHour(_ base: Int, meridiem: Substring) -> (hour: Int, nextDay: Bool) {
        switch meridiem {
        case "manha", "madrugada": (base == 12 ? 0 : base, false)
        case "tarde": (base < 12 ? base + 12 : base, false)
        default: base == 12 ? (0, true) : (base < 12 ? base + 12 : base, false)
        }
    }

    /// "9am", "3pm", "7:30 pm": the meridiem settles the half of the day.
    static func englishClocks(in source: TextSource) -> [Piece<Value>] {
        source.matches(of: englishClock, whenAny: ["am", "pm"], orDigit: true).compactMap { match in
            let (_, hourText, minuteText, meridiem) = match.output
            guard let hour = Int(hourText), (1...12).contains(hour) else { return nil }
            let minute = minuteText.flatMap { Int($0) } ?? 0
            guard (0...59).contains(minute) else { return nil }
            let clockHour = meridiem == "pm" ? (hour == 12 ? 12 : hour + 12) : (hour == 12 ? 0 : hour)
            return Piece(
                range: match.range,
                value: .clock(hour: clockHour, minute: minute, ambiguous: false, nextDay: false))
        }
    }

    // "9am", "3pm", "7:30 pm", "10 AM"
    static var englishClock: Regex<(Substring, Substring, Substring?, Substring)> {
        RegexCache.regex {
            #/\b(\d{1,2})(?::(\d{2}))? ?(am|pm)\b/#.wordBoundaryKind(.simple)
        }
    }

    /// A time zone named after a clock time: "15h BRT", "10h UTC", "16h
    /// GMT-3", "às 9 horário de Brasília". Alone it is no time.
    static func zones(in source: TextSource) -> [Piece<Value>] {
        source.matches(of: zone, whenAny: zoneWords).compactMap { match in
            let (_, place, name, sign, hours, minutes) = match.output
            let zone: TimeZone?
            if let sign, let hours = Int(hours ?? ""), hours <= 14 {
                let seconds = hours * 3600 + (minutes.flatMap { Int($0) } ?? 0) * 60
                zone = TimeZone(secondsFromGMT: sign == "-" ? -seconds : seconds)
            } else {
                zone = (place ?? name).flatMap { zoneNames[String($0)] }.flatMap(TimeZone.init(identifier:))
            }
            return zone.map { Piece(range: match.range, value: .zone($0)) }
        }
    }

    static let zoneWords: Set<String> = [
        "horario", "hora", "brt", "utc", "gmt", "est", "edt", "pst", "pdt", "cet", "cest",
    ]

    /// Places and abbreviations, by the time zone they name.
    static let zoneNames = [
        "brasilia": "America/Sao_Paulo", "sao paulo": "America/Sao_Paulo", "sp": "America/Sao_Paulo",
        "brt": "America/Sao_Paulo", "manaus": "America/Manaus", "acre": "America/Rio_Branco",
        "lisboa": "Europe/Lisbon", "portugal": "Europe/Lisbon", "londres": "Europe/London",
        "nova york": "America/New_York", "nova iorque": "America/New_York",
        "utc": "UTC", "gmt": "UTC", "est": "America/New_York", "edt": "America/New_York",
        "pst": "America/Los_Angeles", "pdt": "America/Los_Angeles", "cet": "Europe/Paris",
        "cest": "Europe/Paris",
    ]

    // "horário de Brasília", "no horário de SP", "BRT", "UTC", "GMT-3", "UTC+05:30"
    static var zone: Regex<(Substring, Substring?, Substring?, Substring?, Substring?, Substring?)> {
        RegexCache.regex {
            #/\b(?:(?:no |pelo |pela )?(?:horario|hora) (?:de|do|da) (brasilia|sao paulo|sp|manaus|acre|lisboa|portugal|londres|nova york|nova iorque)|(brt|utc|gmt|est|edt|pst|pdt|cet|cest)(?:([+-])(\d{1,2})(?::?(\d{2}))?)?)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    static func noonAndMidnight(in source: TextSource) -> [Piece<Value>] {
        source.matches(of: noonOrMidnight, whenAny: noonWords).compactMap { match in
            let (_, prefix, word, minuteWords) = match.output
            // "Meio dia" as two words without "ao" may mean half a day: "meio dia de folga".
            if word == "meio dia", prefix == nil { return nil }
            let minute = minuteWords.map { $0 == "meia" ? 30 : SpokenNumber.value($0) ?? 0 } ?? 0
            let midnight = word.hasPrefix("meia")
            return Piece(
                range: match.range,
                value: .clock(hour: midnight ? 0 : 12, minute: minute, ambiguous: false, nextDay: midnight))
        }
    }

    /// "daqui 2 horas" ahead; "há 2 horas" and "20 minutos atrás" back.
    static func fromNow(in source: TextSource) -> [Piece<Value>] {
        let found =
            source.matches(of: inTime, whenAny: DayRules.amountWords).map {
                ($0.range, $0.output.1, $0.output.2, 1)
            }
            + source.matches(of: agoTime, whenAny: DayRules.agoWords).map {
                ($0.range, $0.output.1, $0.output.2, -1)
            }
            + source.matches(of: timeAgo, whenAny: DayRules.backWords).map {
                ($0.range, $0.output.1, $0.output.2, -1)
            }
        return found.compactMap { range, amount, unit, sign in
            let hours = unit.hasPrefix("hora")
            let minutes: Int
            if amount == "meia" {
                guard hours else { return nil }
                minutes = 30
            } else {
                guard let count = SpokenNumber.value(amount) else { return nil }
                minutes = hours ? count * 60 : count
            }
            return Piece(range: range, value: .fromNow(minutes: sign * minutes))
        } + vagueTimes(in: source)
    }

    /// "daqui a pouco" is half an hour from now and "mais tarde" two hours;
    /// see docs on the decision. "agora" is left out: it is too common an
    /// adverb to mean a reminder right now.
    static func vagueTimes(in source: TextSource) -> [Piece<Value>] {
        source.matches(of: vagueTime, whenAny: vagueWords).compactMap { match in
            vagueMinutes[String(match.output.1)].map {
                Piece(range: match.range, value: .fromNow(minutes: $0))
            }
        }
    }

    static let vagueMinutes = [
        "daqui a pouquinho": 30, "daqui a pouco": 30, "daqui pouquinho": 30, "daqui pouco": 30, "ja ja": 30,
        "hoje mais tarde": 120, "mais tarde hoje": 120, "mais tarde": 120, "logo mais": 120,
    ]
    static let vagueWords: Set<String> = ["pouco", "pouquinho", "ja", "tarde", "logo"]

    // "daqui a pouco", "já já", "mais tarde", "logo mais"
    static var vagueTime: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b(daqui a pouquinho|daqui a pouco|daqui pouquinho|daqui pouco|ja ja|hoje mais tarde|mais tarde hoje|mais tarde|logo mais)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    /// Hours with duration words around them: "por 2 horas", "há 1h30",
    /// "8h por dia", "8 horas diárias".
    static func isDuration(_ range: Range<String.Index>, in source: TextSource) -> Bool {
        if let before = source.word(before: range.lowerBound), durationWords.contains(before) { return true }
        let after = source.words(after: range.upperBound, count: 2)
        return rateWords.contains { after.starts(with: $0) }
    }

    // Words the clock rules need before their regex is worth running; a digit
    // also opens them. See `DayRules.relativeDayWords`.
    static let hourWords: Set<String> = [
        "uma", "duas", "tres", "quatro", "cinco", "seis", "sete", "oito", "nove", "dez", "onze", "doze",
        "treze",
        "catorze", "quatorze", "quinze", "dezesseis", "dezessete", "dezoito", "dezenove", "vinte",
    ]
    static let towardWords: Set<String> = ["para", "pras", "pra", "pro"]
    static let noonWords: Set<String> = ["meio", "meia"]

    /// Words before an hour that also come before a count: "umas 8
    /// laranjas", "por volta de 10 pessoas".
    static let approximateWords: Set<String> = [
        "umas", "pras", "por volta de", "em torno de", "perto de", "cerca de",
    ]

    static let durationWords: Set<String> = [
        "por", "durante", "ha", "faz", "cada", "daqui", "em", "apos", "umas", "uns",
    ]

    static let rateWords: [[String]] = [
        ["por", "dia"], ["por", "noite"], ["por", "semana"], ["por", "mes"], ["ao", "dia"],
        ["diarias"], ["diarios"], ["semanais"], ["seguidas"], ["seguidos"],
    ]

    // Computed, not stored: `Regex` is not `Sendable`. `RegexCache` keeps each
    // one built per thread. The text arrives without accents or punctuation.

    // "às 9", "14h", "9h30", "10:30", "15:30h", "15h30min", "às 7 e meia", "às sete da noite", "3 da tarde",
    // "às vinte e duas horas", "às oito e trinta e cinco"
    static var clock:
        Regex<(Substring, Substring?, Substring, Substring?, Substring?, Substring?, Substring?, Substring?)>
    {
        RegexCache.regex {
            #/\b(?:(as|ate as|pelas|la pelas|la pras|la para as|por volta das|em torno das|perto das|a partir das|das|umas|pras|por volta de|em torno de|perto de|cerca de) )?(\d{1,2}|vinte e uma|vinte e um|vinte e duas|vinte e dois|vinte e tres|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|duas|uma)(?:(:|h)(\d{2})(?:hs|h|min|m)?\b|( ?(?:hrs|hr|hs|horas|hora|h))\b|\b)(?: e (meia|(?:vinte|trinta|quarenta|cinquenta) e (?:um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove)|vinte|trinta|quarenta|cinquenta|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|cinco|\d{1,2})\b)?(?: (?:da|de|pela) (manha|tarde|noite|madrugada)\b)?/#
                .wordBoundaryKind(.simple)
        }
    }

    // "quinze para as oito", "vinte e cinco pras 9", "10 minutos para as 3 da tarde"
    static var minutesTo: Regex<(Substring, Substring, Substring?, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(?:(?:as|pelas|la pelas|por volta das|ate as) )?(vinte e cinco|cinco|dez|quinze|vinte|\d{1,2})( min| minutos)? (?:para as|para a|para o|pras|pra as|pra a|pro) (\d{1,2}|uma|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze|meio-dia|meio dia|meia-noite|meia noite)\b(?: (?:da|de|pela) (manha|tarde|noite|madrugada)\b)?/#
                .wordBoundaryKind(.simple)
        }
    }

    // "de 9 a 11h", "entre 10 e 11h", "10 às 12", "9-10h"
    static var bareRangeStart: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:(?:de|entre) )?(\d{1,2}|vinte e uma|vinte e um|vinte e duas|vinte e dois|vinte e tres|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|duas|uma)\b(?= ?-| (?:a|as|ate|e) )/#
                .wordBoundaryKind(.simple)
        }
    }

    // "ao meio-dia", "meio-dia e meia", "à meia-noite"
    static var noonOrMidnight: Regex<(Substring, Substring?, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(?:(ao|a|as|no|pelo|pela|por volta do|por volta da|la pelo|la pela|la pro|la pra|em torno do|em torno da|perto do|perto da|perto de|em torno de|por volta de|ate o|ate a) )?(meio-dia|meio dia|meia-noite|meia noite)(?: e (meia|quinze|vinte|trinta|quarenta|cinco|dez|\d{1,2})\b)?\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "há 2 horas", "faz meia hora", "há umas 2 horas atrás"
    static var agoTime: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:ha|faz) (?:umas |uns |cerca de )?(\d{1,3}|uma|um|duas|dois|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta|quarenta|cinquenta|meia) (horas?|minutos?|min)\b(?: atras\b)?/#
                .wordBoundaryKind(.simple)
        }
    }

    // "20 minutos atrás"
    static var timeAgo: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(\d{1,3}|uma|um|duas|dois|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta|quarenta|cinquenta|meia) (horas?|minutos?|min) atras\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "daqui 2 horas", "em meia hora", "daqui a 20 minutos", "em uns 15 minutos"
    static var inTime: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:daqui a|daqui|em ate|em|dentro de ate|dentro de|no prazo de|com prazo de|prazo de) (?:umas |uns |cerca de )?(\d{1,3}|uma|um|duas|dois|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta|quarenta|cinquenta|meia) (horas?|minutos?|min)\b/#
                .wordBoundaryKind(.simple)
        }
    }
}
