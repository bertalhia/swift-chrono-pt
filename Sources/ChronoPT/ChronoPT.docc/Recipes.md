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
// A date with no time ("amanhã") or the whole day ("o dia todo").
event.isAllDay = match.isAllDay || !match.start.hasTime
if let span = match.dateInterval {
    event.startDate = span.start
    event.endDate = span.end
} else {
    event.startDate = match.start.date
    event.endDate = match.start.date.addingTimeInterval(3600)
}
```

``ChronoPT/Match/dateInterval`` covers whole days for a date with no time,
and runs from the start to the end of a time range. A single moment ("às 9")
has none.

## Repeat an event

``ChronoPT/Recurrence`` has the fields of an iCalendar rule, the same ones
`EKRecurrenceRule` takes:

```swift
func rule(for recurrence: ChronoPT.Recurrence) -> EKRecurrenceRule? {
    let frequency: EKRecurrenceFrequency
    switch recurrence.frequency {
    case .daily: frequency = .daily
    case .weekly: frequency = .weekly
    case .monthly: frequency = .monthly
    case .yearly: frequency = .yearly
    case .hourly, .minutely: return nil  // a series of alarms, not an event
    }
    let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    let days = recurrence.weekdays.compactMap { day in
        weekdays.firstIndex(of: day.weekday).flatMap { EKWeekday(rawValue: $0 + 1) }
            .map { EKRecurrenceDayOfWeek($0, weekNumber: day.ordinal ?? 0) }
    }
    let end: EKRecurrenceEnd? =
        switch recurrence.end {
        case .until(let date): EKRecurrenceEnd(end: date)
        case .count(let count): EKRecurrenceEnd(occurrenceCount: count)
        case nil: nil
        }
    return EKRecurrenceRule(
        recurrenceWith: frequency, interval: recurrence.interval,
        daysOfTheWeek: days.isEmpty ? nil : days,
        daysOfTheMonth: recurrence.daysOfMonth.isEmpty ? nil : recurrence.daysOfMonth.sorted().map { $0 as NSNumber },
        monthsOfTheYear: recurrence.months.isEmpty ? nil : recurrence.months.sorted().map { $0 as NSNumber },
        weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: end)
}
```

An `EKRecurrenceRule` has no times of day: for "todo dia às 8h e às 20h",
make one event for each of ``ChronoPT/Recurrence/timesOfDay``. A
``ChronoPT/Recurrence/rate`` ("3x ao dia") has no field in any rule: the app
picks the hours. For an iCalendar file or a CalDAV server,
``ChronoPT/Recurrence/rrule`` gives the `RRULE` value, times of day included.

## Offer the other reading

When ``ChronoPT/PartialDate/alternative`` is not `nil`, the text named an hour
without saying morning or evening. Show the chosen date and let the person
switch to the alternative.

## Parse many texts the same way

``ChronoPT/Parser`` keeps a calendar and options. It is `Sendable`, and parsing
is safe from any thread. The regexes are compiled once for the process, which
costs about 10 ms on the first call, and shared by every thread after that.
