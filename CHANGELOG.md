# Changelog

Versions follow [semantic versioning](https://semver.org). While the package is
`0.x`, a minor release may break the API and a patch release may not.

## 0.9.0

### Added

- `ChronoPT.Parser` keeps a calendar and options for an app that reads many
  texts the same way.
- `PartialDate.alternative`: "às 7" reads as 19:00, and the alternative holds
  7:00, so a UI can offer it.
- Dates counted from another: "dois dias antes do natal", "véspera do ano
  novo", "uma semana depois do dia 10".
- Vague times: "daqui a pouco" (30 minutes) and "mais tarde" (2 hours).
  "agora" alone stays unread.
- Date formats: "10/out", "25-12-2027", "25.12.2027", "dez/2027", "12/2027".
- `Recurrence` has a stable `description`, weekdays in week order.
- DocC articles: getting started, the grammar, and recipes.

### Changed

- A time counted from now joins a day when it lands on that day: "hoje mais
  tarde" is two hours from now.

### Performance

- Rules skip their regex when the text holds none of the words it needs. In a
  release build, 10 KB of text with no date goes from 105 ms to 2.3 ms, 7.7 KB
  of notes from 118 ms to 28 ms, and a one-line note from 1.1 ms to 0.28 ms.
- Normalization no longer allocates per character, and the part-of-day table
  is indexed by first word instead of searched 102 times.

## 0.8.0

### Breaking

- The public types moved into the `ChronoPT` namespace: `ChronoPT.Match`,
  `ChronoPT.PartialDate`, `ChronoPT.Options` and `ChronoPT.Recurrence`. An app
  with its own `Recurrence` keeps compiling.

### Added

- `ChronoPT.strippingDates(from:)` returns the text without the dates, along
  with the word that introduced each one: "comprar pão amanhã no almoço" gives
  "comprar pão".
- `Match.ranges`, every span that produced the date, so a time said apart from
  its day can be highlighted or removed too.
- `Match.interval`, `PartialDate.hasDay`, `PartialDate.dateComponents(in:)`,
  public initializers, `Hashable` on every type, `Codable` on `Options` and
  `Recurrence`, and a debug description that prints the text and the date.
- Business days: "em 5 dias úteis", "no próximo dia útil", "primeiro dia útil
  do mês", counting the national holidays and the three the banks close for.
- Deadlines: "prazo de 5 dias", "em até 48 horas".
- Years in amounts: "daqui a 1 ano", "em 2 anos", "há 3 anos".
- Periods: "fim do ano", "no início do mês", "no meio da semana", and a month
  on its own ("férias em dezembro", "março de 2027").
- Intervals of hours and minutes: "de 8 em 8 horas", "a cada 30 minutos".
- Ordinal indicators and numbered weekdays: "dia 1º", "6ª feira", "toda 2ª
  feira"; "sábado agora" and "quinta dessa semana"; more parts of the day
  ("no comecinho da tarde", "na boquinha da noite", "de madruga").

### Fixed

- Parsing was cubic: 2.4 KB of repeated weekdays took 13 seconds and a pasted
  note could freeze a UI thread. It now takes 105 ms. The regexes were never
  the problem; the candidate pair loops asked questions that scanned the rest
  of the text.
- A time counted from now no longer takes over a day said in the same text:
  "consulta dia 30, sair daqui a 20 minutos" is the 30th.
- "sáb - 3/10" is that date, not a range from Saturday to it. Two rules
  produced the same span and the winner depended on the sort being stable.
- Any calendar is honoured: a Buddhist calendar used to give 1483 for
  "25/09/2026", and every movable holiday moved.
- A time inside a daylight saving gap stays on its day.
- Normalization keeps one character for each character, so a combining mark
  after a line break no longer shifts every range after it.
- "da meia-noite à meia-noite" is a whole day.
- Digits that are not ASCII are no longer read as zero.
- "fim de semana que vem" and "fim do mês que vem" matched the shorter phrase.
- "de manhã bem cedo" gave 9:00, "reunião 10 às 12" gave a single 12:00,
  "de 8 em 8 horas" lost its recurrence, and "em 5 dias úteis" gave a Saturday.

## 0.7.0

- `Recurrence.every(DateComponents)` for "a cada 15 dias", "de 2 em 2 semanas",
  "toda semana", "mensalmente".
- A weekday after a time counts with "de": "às 10 de quinta".

## 0.6.0

### Breaking

- `ParsedResult` gained `start` and `end` of type `ParsedDate`, in place of
  `date`, `end` and `hasTime`.

### Added

- `knownComponents`: which parts of the date the text fixed, so an app can show
  "25/09" without inventing a year.

## 0.5.0

- `ParseOptions` with `allowsPast` ("ontem", "sexta passada", "há 2 dias") and
  `defaultHour`.
- `recurrence`: "toda terça", "todo dia às 8", "todo dia 5".

## 0.4.0

- Abbreviations: "na seg", "qua 14h", "amn", "dps do almoço", "prox sexta".
- More written times ("15:30h", "15h30min") and forms common in Portugal.
- Agenda ranges without an opening word: "14h às 16h", "10h-11h", "seg-sex".
- Compiled regexes are kept per thread: `parse` went from 11 ms to 0.58 ms.
- A corpus of 60 notes written the way people write them.

## 0.3.0

- Day and time ranges fill `end`: "das 14h às 16h", "de segunda a sexta",
  "do dia 10 ao dia 15", "de 10 a 15 de outubro".

## 0.2.0

- Compound spelled-out numbers, minutes before the hour, Brazilian holidays,
  and more named periods.

## 0.1.1

- A part of the day settles a clock time said later; hours per day are a
  duration; CI on macOS and Linux.

## 0.1.0

- First release: relative days, weekdays, dates, periods, clock times, parts of
  the day and meals.
