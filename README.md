# ChronoPT

[![Tests](https://github.com/bertalhia/swift-chrono-pt/actions/workflows/tests.yml/badge.svg)](https://github.com/bertalhia/swift-chrono-pt/actions/workflows/tests.yml)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbertalhia%2Fswift-chrono-pt%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/bertalhia/swift-chrono-pt)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbertalhia%2Fswift-chrono-pt%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/bertalhia/swift-chrono-pt)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Natural-language date and time parsing for Brazilian Portuguese, in Swift.

```swift
import ChronoPT

let reminder = ChronoPT.interpret("comprar pão amanhã no almoço")
reminder?.start.date  // tomorrow at 12:00
reminder?.text        // "amanhã no almoço"
```

ChronoPT reads text the way people write notes and reminders in Brazil:
"sexta às 14h", "depois da janta", "dia 30 à noite", "de segunda a sexta das
9 às 18". It is a small rule-based grammar in the style of
[chrono](https://github.com/wanasit/chrono), with no network access, no
language model and no `NSDataDetector`. The same text with the same reference
date always gives the same result.

- [What it understands](#what-it-understands)
- [Installation](#installation)
- [Usage](#usage)
- [Options](#options)
- [Integration](#integration)
- [How it reads ambiguous text](#how-it-reads-ambiguous-text)
- [Not supported yet](#not-supported-yet)
- [Contributing](#contributing)
- [Em português](#em-português)

## What it understands

| Kind | Examples |
|---|---|
| Relative day | hoje, hj, amanhã, amn, depois de amanhã, daqui 2 dias, em três semanas, daqui um mês |
| Weekday | sexta que vem, próxima sexta, nesta quinta, na terça-feira, sábado, quarta da semana que vem, sexta dia 25, sexta 25, na seg, prox sexta |
| Date | 25/09, 25/09/2026, 25-12-2027, 25.12.2027, 10/out, 2026-10-15, 15 de outubro, vinte e três de outubro, 1º de maio, dia 30, dia quinze |
| Period | esta semana, semana que vem, fim de semana, no meio da semana, este mês, mês que vem, no início do mês, no meio do mês, fim do mês, primeira quinzena de outubro, em outubro, março de 2027, dez/2027, 12/2027, no próximo trimestre, primeiro semestre, ano que vem, fim do ano |
| Holiday | no natal, véspera de natal, no ano novo, na páscoa, no carnaval, sexta-feira santa, corpus christi, dia de finados, dia das mães, dia dos pais |
| Clock time | às 9, 14h, 9h30, 10:30, 15:30h, 9am, 7:30 pm, umas 8 da noite, lá pras 3, por volta de 15h, perto do meio-dia, 15h BRT, 16h GMT-3, às 9 horário de Brasília, às 7 e meia, às sete da noite, às vinte e duas horas, 3 da tarde, quinze para as oito, meio-dia e meia, à meia-noite |
| Part of the day | de manhã, à tarde, à noite, de madrugada, cedo, à tardinha, tarde da noite, no fim da tarde, a tarde toda, a noite inteira |
| Moment | no almoço, na janta, depois do almoço, antes de dormir, ao acordar, no café da manhã, depois do trabalho |
| From now | daqui 2 horas, em meia hora, daqui a 20 minutos, em uns 15 minutos, daqui a pouco, mais tarde, logo mais |
| Counted from a date | dois dias antes do natal, véspera do ano novo, uma semana depois do dia 10, 3 dias antes de 25/10 |
| Business days | em 5 dias úteis, prazo de 2 dias úteis, no próximo dia útil, primeiro dia útil do mês, último dia útil do mês |
| Range | das 14h às 16h, 14h às 16h, 10h-11h, de 9 a 11h, entre 10 e 11h, de segunda a sexta, seg-sex, do dia 10 ao dia 15, de 10 a 15 de outubro, por 3 dias, amanhã por uma semana, nos próximos 5 dias, durante a semana |
| Repeating | todo dia, todos os dias, toda terça, todas as sextas, às segundas e quartas, todo dia 5, todo mês no dia 10, a cada 15 dias, de 2 em 2 semanas, toda semana, mensalmente, 3x ao dia, duas vezes por semana, dia sim dia não, toda última sexta do mês, todo ano em julho, todo 25 de dezembro, toda terça até dezembro, todo dia por 10 dias, toda segunda 5 vezes |
| Past | ontem, anteontem, sexta passada, na última sexta, semana passada, semana retrasada, mês passado, mês retrasado, há 2 dias, 3 dias atrás, há duas semanas atrás, há 2 horas |

Past dates count only with `allowsPast` (see [Options](#options)).

ISO dates with a time, such as "2026-10-15T14:30" or "2026-10-15T14:30:00-03:00",
give that moment, in the offset they carry or else in the calendar's time zone.

Accents and capitals are optional: "AMANHA as 9" and "no almoco" work too. So
do forms common in Portugal, such as "pelas 9", "às 15h00", "ao pequeno-almoço"
and "ao fim da tarde".

## Installation

Add the package in Xcode with **File › Add Package Dependencies…** and the URL
`https://github.com/bertalhia/swift-chrono-pt.git`, or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bertalhia/swift-chrono-pt.git", from: "0.11.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "ChronoPT", package: "swift-chrono-pt")
    ])
]
```

Requires Swift 6.0 or later. Runs on iOS 16, macOS 13, watchOS 9, tvOS 16,
visionOS 1 and Linux.

## Usage

### One date for the whole text

`interpret` returns the date a note points to: the first day mentioned, at the
time next to it or, if there is none, at the first time mentioned anywhere in
the text. It returns `nil` when the text has no date.

```swift
let note = ChronoPT.interpret("amanhã de manhã, reunião às 7")
note?.start.date     // tomorrow at 7:00
note?.start.hasTime  // true
```

### Every date in the text

`parse` returns every expression, in the order it appears. Use `range` to
highlight it in the original string.

```swift
let text = "dentista sexta às 14h, reunião dia 30 e ligar pro banco amanhã"
let found = ChronoPT.parse(text)
found.map(\.text)  // ["sexta às 14h", "dia 30", "amanhã"]
text[found[0].range]  // "sexta às 14h"
```

### Periods and ranges

Periods and ranges also fill `end`.

```swift
let shift = ChronoPT.interpret("plantão de segunda a sexta das 9 às 18")
shift?.start.date  // next Monday at 9:00
shift?.end?.date   // that Friday at 18:00
```

A whole part of the day is a range too: "a manhã toda" runs from 6:00 to
12:00. The whole day has no hours, so it sets `isAllDay` instead, for an
all-day event:

```swift
let offsite = ChronoPT.interpret("amanhã o dia todo")
offsite?.isAllDay       // true
offsite?.start.hasTime  // false
```

### Repeating dates

`recurrence` says how a date repeats, and `date` is the next time it happens,
counting today.

```swift
let chore = ChronoPT.interpret("tirar o lixo toda terça às 20h")
chore?.start.date  // next Tuesday at 20:00
chore?.recurrence  // .weekly(on: [.tuesday])

let water = ChronoPT.interpret("regar as plantas a cada 15 dias")
water?.recurrence  // .daily(every: 15)

let lessons = ChronoPT.interpret("aula toda terça até dezembro")
lessons?.recurrence?.rrule  // "FREQ=WEEKLY;BYDAY=TU;UNTIL=20270101T025959Z"
```

`Recurrence` follows the iCalendar rule (RFC 5545): a frequency, an interval,
the weekdays, days of the month and months it falls on, and an `end`, a date
or a count. `rrule` writes it out for a calendar server; for EventKit, see the
recipe in the documentation.

### Options

Past dates are off by default, since a reminder in the past is useless. A day
with no time is set to noon.

```swift
let options = ChronoPT.Options(allowsPast: true, defaultHour: 9)
let paid = ChronoPT.interpret("paguei ontem", options: options)
paid?.start.date  // yesterday at 9:00
```

`allowsPast` covers words that point back, such as "ontem", "sexta passada"
or "há 2 dias". A date that only names a day, such as "dia 15" or "sexta",
still means the next one.

`moments` adds your app's own phrases, with the hour each one means. They read
like "no almoço", and win over a built-in phrase written the same way:

```swift
let gym = ChronoPT.Options(moments: ["no treino": 7, "na consulta": 14])
ChronoPT.interpret("amanhã no treino", options: gym)?.start.date  // tomorrow at 7:00
```

### The text without the date

A notes app wants the title without the date, and cleaning that by hand leaves
the prepositions and punctuation behind.

```swift
ChronoPT.strippingDates(from: "comprar pão amanhã no almoço")
// "comprar pão"

ChronoPT.strippingDates(from: "dentista sexta às 14h, reunião dia 30")
// "dentista, reunião"
```

### A parser set up once

An app that reads many texts the same way can keep the calendar and options
in one place; only the reference date changes, and it defaults to now.

```swift
let parser = ChronoPT.Parser(calendar: calendar, options: .init(defaultHour: 9))
parser.interpret("pagar o aluguel dia 5")
parser.strippingDates(from: "comprar pão amanhã")  // "comprar pão"
```

### Reference date and calendar

Relative expressions are computed from `reference`, which defaults to now.
Midnight and the time zone come from `calendar`, which defaults to
`Calendar.current`. Pass both on servers and in tests:

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!

let result = ChronoPT.interpret("sexta à noite", reference: someDate, calendar: calendar)
```

Any calendar works. The grammar counts Gregorian months, weekdays, holidays
and years, so a Buddhist or Hebrew calendar keeps its time zone and the
arithmetic runs in Gregorian: "25/09/2026" is the same instant either way. A
week runs Monday to Sunday whatever `firstWeekday` says, because that is what
the Portuguese words mean.

### The result

```swift
public struct ChronoPT.Match: Sendable, Hashable {
    public let range: Range<String.Index>    // the day, with the time when they touch
    public let ranges: [Range<String.Index>] // every span that produced the date
    public let text: String                  // the expression as written
    public let start: ChronoPT.PartialDate
    public let end: ChronoPT.PartialDate?    // the end of a period or a range
    public let recurrence: ChronoPT.Recurrence?
    public let isAllDay: Bool                // "amanhã o dia todo"
    public let dateInterval: DateInterval?   // whole days, or a time range
}

public struct ChronoPT.PartialDate: Sendable, Hashable {
    public let date: Date
    public let knownComponents: Set<Calendar.Component>  // what the text fixed
    public var hasTime: Bool                             // the text gave an hour
    public var hasDay: Bool                              // the text gave a day
    public let alternative: Date?                        // 7:00 for "às 7", read as 19:00
    public let timeZone: TimeZone?                       // "15h BRT"
    public func dateComponents(in: Calendar) -> DateComponents
}
```

A day without a time is set to noon, or to `defaultHour`, away from the
midnight shifts of daylight saving time. Check `hasTime` before showing the
hour. `dateInterval` is what a calendar shows: whole days for a date with no
time ("amanhã" is the whole of tomorrow), start to end for a time range.

### What the text gave

`knownComponents` says which parts of the date the text fixed. The rest comes
from the reference date, so you can show "25/09" without inventing a year.

```swift
ChronoPT.interpret("25/09")?.start.knownComponents       // [.day, .month]
ChronoPT.interpret("25/09/2027")?.start.knownComponents  // [.day, .month, .year]
ChronoPT.interpret("às 9")?.start.knownComponents        // [.hour, .minute]
```

Every public symbol has documentation comments. To browse them as DocC
documentation, open the package in Xcode and choose **Product › Build
Documentation**.

## Integration

- **`nil` means no date.** Nothing throws: `interpret` returns `nil` and `parse`
  an empty array when the text has no date in it.
- **Any thread.** `parse`, `interpret`, `strippingDates` and `Parser` are pure
  functions, safe from any thread or actor, and every result is `Sendable`.
  Each thread keeps its own compiled regexes, so the first call on a new
  thread takes about 10 ms longer.
- **Cost.** In a release build on Apple silicon: 0.28 ms for a one-line note,
  28 ms for 7.7 KB of notes full of dates, 2.3 ms for 10 KB of text with none.
- **Highlighting.** For UIKit, `NSRange(match.range, in: text)`. For SwiftUI,
  convert each of `match.ranges`, which includes a time said apart from its
  day:

  ```swift
  var attributed = AttributedString(text)
  for match in ChronoPT.parse(text) {
      for range in match.ranges {
          guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
              let upper = AttributedString.Index(range.upperBound, within: attributed)
          else { continue }
          attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
      }
  }
  ```

- **Locale and time zone.** `calendar.timeZone` decides the instants, unless
  the text names a zone: "15h BRT", "10h UTC", "16h GMT-3", "às 9 horário de
  Brasília". Then the clock time is read in that zone, on the calendar's day,
  and `knownComponents` has `.timeZone`. `calendar.locale` does not change
  what is read, and `firstWeekday` is ignored, since a Portuguese week runs
  Monday to Sunday.
- **European Portuguese.** Common forms work ("pelas 9", "às 15h00", "ao
  pequeno-almoço", "ao fim da tarde"), but the grammar is written for Brazil
  first.

## How it reads ambiguous text

- "daqui a pouco" is 30 minutes from now and "mais tarde" 2 hours. "agora" on
  its own is not read: it is too common an adverb to mean a reminder right
  now.
- A time with no day is today, or tomorrow if that time has passed. A
  repeating date works the same way: "toda segunda às 9" said on a Monday at
  10:00 is next Monday.
- A weekday is the next one, not counting today: "sexta" said on a Friday is
  next week's.
- Spoken "às 7" is 19:00, the way people say it, and written "7h" is 7:00.
  `start.alternative` holds the other reading, 7:00, so a UI can offer it. A
  part of the day decides: "de manhã, às 7" and "amanhã de manhã, reunião às
  7" are 7:00.
- On a single day, an hour that did not say morning or evening takes the
  reading that has not passed: "hoje às 9" said at 10:00 is 21:00. A
  repeating day keeps its reading, and its other reading is the next one.
- "as" and "das" without an accent are also articles, so before a bare number
  they need the end of a phrase: "chego as 3" is a time, "buscar as 2
  crianças" is not. "às" and "à" are always a time.
- A number a day holds is not an hour: "dia 10 às 14h" is the 10th at 14:00,
  and "sala 12 às 15h" is 15:00. Without "de" or "entre", a bare number opens
  a range only at the start of a phrase or right after a day: "amanhã 10 às
  12".
- Two clock times are two times unless a range joins them: "às 8h e às 20h".
  A day and a time in different sentences stay apart.
- In a range, an ambiguous end is the first reading after the start: "das 7
  às 9" is 19:00 to 21:00, and "das 7 às 9 da manhã" is 7:00 to 9:00.
- "para a janta" is not a time. Only "na janta" or "no almoço", with a
  preposition of time, set one: "comprar para a janta amanhã" (buy for
  tomorrow's dinner) is tomorrow, with no time.
- Ordinals are not weekdays: "segunda via do boleto" (a duplicate bill) and
  "quinta série" (fifth grade) are not dates. Monday to Friday need a hint,
  such as "na segunda", "segunda-feira", "sexta que vem", a time right after
  ("quinta às 14h") or a range ("de segunda a sexta").
- A duration is not a time: "estudar por 2 horas", "trabalhar 8h por dia" and
  "reunião de 2h" set no time.
- A holiday name with another meaning needs a preposition: "no natal" is
  Christmas, "voo para Natal" is the city, and "ovo de páscoa" is not a date.
- Midnight of a day is the start of the next day.
- A whole part of the day runs from 6:00 to 12:00 for the morning, 12:00 to
  18:00 for the afternoon, 18:00 to midnight for the night, and midnight to
  6:00 for "a madrugada toda". "o dia todo" needs a day: "choveu o dia todo"
  is not a date.

## Not supported yet

- "ter" is read as the verb "to have", never as Tuesday: write "terça".
- A weekday after a time needs "de": "às 10 de quinta" is Thursday, but "às 10
  quinta" is not.

What is missing is tracked in
[issues](https://github.com/bertalhia/swift-chrono-pt/issues).
Bug reports are welcome: include the text, the reference date and time zone,
the result you got and the one you expected.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Every new case comes with a test, and
`swift test` runs on macOS and Linux in CI.

## Em português

Parser de data e hora em linguagem natural para português do Brasil, em
Swift. Entende dia relativo, dia da semana, data, período, feriado, horário,
parte do dia, refeição e intervalo ("amanhã no almoço", "sexta à noite",
"depois da janta", "de segunda a sexta das 9 às 18"). Não usa rede, modelo de
linguagem nem `NSDataDetector`: o mesmo texto, com a mesma data de
referência, dá sempre o mesmo resultado.

## License

MIT. See [LICENSE](LICENSE).
