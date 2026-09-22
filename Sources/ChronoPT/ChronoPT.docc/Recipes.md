# Recipes

Common ways to use a match in an app.

## Keep the title without the date

```swift
let title = ChronoPT.strippingDates(from: "dentista sexta às 14h")
// "dentista"
```

## Highlight the match

``ChronoPT/Match/ranges`` holds every span that produced the date, including
a time said apart from its day. For UIKit, convert each with
`NSRange(range, in: text)`. For SwiftUI:

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

## Create a calendar event

```swift
import EventKit

let event = EKEvent(eventStore: store)
event.title = ChronoPT.strippingDates(from: note)
event.startDate = match.start.date
event.endDate = match.end?.date ?? match.start.date.addingTimeInterval(3600)
event.isAllDay = !match.start.hasTime
```

``ChronoPT/Match/interval`` gives the span as a `DateInterval` when the
expression has an end. For a repeating date, map ``ChronoPT/Recurrence`` to an
`EKRecurrenceRule`: `.daily` to `.daily`, `.weekly(on:)` to `.weekly` with
`daysOfTheWeek`, `.monthly(day:)` to `.monthly` with `daysOfTheMonth`, and
`.every(_:)` to the frequency and interval its components name.

## Offer the other reading

When ``ChronoPT/PartialDate/alternative`` is not `nil`, the text named an hour
without saying morning or evening. Show the chosen date and let the person
switch to the alternative.

## Parse many texts the same way

``ChronoPT/Parser`` keeps a calendar and options. It is `Sendable`, and parsing
is safe from any thread; each thread builds its regexes once, which costs
about 10 ms on the first call.
