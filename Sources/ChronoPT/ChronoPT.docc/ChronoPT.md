# ``ChronoPT``

Natural-language date and time parsing for Brazilian Portuguese.

## Overview

ChronoPT finds dates and times in text written the way people write notes in
Brazilian Portuguese: "amanhã no almoço", "sexta às 14h", "dia 30 à noite".

```swift
let reminder = ChronoPT.interpret("comprar pão amanhã no almoço")
// reminder?.start.date is tomorrow at 12:00
// reminder?.text is "amanhã no almoço"
```

Use ``ChronoPT/interpret(_:reference:calendar:options:)`` when the whole text is one
note and you want one date for it. Use ``ChronoPT/parse(_:reference:calendar:options:)``
to get every expression in the text, in order.

The parser is deterministic. It doesn't use the network, a language model or
`NSDataDetector`, so the same text with the same reference date and calendar
always gives the same result.

### Reference date and calendar

Relative expressions ("amanhã", "daqui 2 horas") are computed from
`reference`. Midnight and the time zone come from `calendar`; a week runs
Monday to Sunday whatever its `firstWeekday` says. Pass
both explicitly in tests and on servers:

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
let results = ChronoPT.parse(text, reference: now, calendar: calendar)
```

### What the text gave

``ChronoPT/PartialDate/knownComponents`` says which parts of the date the text fixed.
The rest comes from the reference date, so "25/09" gives `[.day, .month]` and
you can show it without inventing a year.

### Repeating and past dates

``ChronoPT/Match/recurrence`` says how a date repeats ("toda terça", "todo dia
às 8", "todo dia 5", "a cada 15 dias", "toda última sexta do mês") and where it
stops ("até dezembro", "por 10 dias"), and ``ChronoPT/Match/start`` is the next
time it happens.
Past dates ("ontem", "sexta passada", "há 2 dias") count only with
``ChronoPT/Options/allowsPast``.

### The text without the date

``ChronoPT/strippingDates(from:reference:calendar:options:)`` gives the text
with every date taken out, along with the word that introduced it, which is
what a notes app keeps as the title.

### An hour that did not say morning or evening

"às 7" reads as 19:00, the way people say it, and
``ChronoPT/PartialDate/alternative`` holds the other reading, 7:00, so a UI
can offer it. A part of the day or a written hour ("de manhã, às 7", "7h")
settles it, and the alternative is `nil`.

### Dates without a time

When the text gives only a day, ``ChronoPT/PartialDate/date`` is noon of that day, or
``ChronoPT/Options/defaultHour``, and ``ChronoPT/PartialDate/hasTime`` is `false`. Noon keeps the date away from the
midnight shifts of daylight saving time.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Grammar>
- <doc:Recipes>

### Parsing

- ``ChronoPT/interpret(_:reference:calendar:options:)``
- ``ChronoPT/parse(_:reference:calendar:options:)``
- ``ChronoPT/strippingDates(from:reference:calendar:options:)``
- ``ChronoPT/Parser``
- ``ChronoPT/Options``

### Results

- ``ChronoPT/Match``
- ``ChronoPT/PartialDate``
- ``ChronoPT/Recurrence``
