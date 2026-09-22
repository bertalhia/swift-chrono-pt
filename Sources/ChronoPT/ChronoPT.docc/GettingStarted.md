# Getting started

Add the package, read a date from a note, and check what the text gave.

## Add the package

In Xcode, choose **File › Add Package Dependencies…** and enter
`https://github.com/bertalhia/swift-chrono-pt.git`. In `Package.swift`:

```swift
.package(url: "https://github.com/bertalhia/swift-chrono-pt.git", from: "0.11.0")
```

and add `.product(name: "ChronoPT", package: "swift-chrono-pt")` to the target.

## Read a date

``ChronoPT/interpret(_:reference:calendar:options:)`` returns the one date a
note points to, or `nil` when it has none. Nothing throws.

```swift
import ChronoPT

if let match = ChronoPT.interpret("comprar pão amanhã no almoço") {
    match.start.date     // tomorrow at 12:00
    match.start.hasTime  // true
    match.text           // "amanhã no almoço"
}
```

``ChronoPT/parse(_:reference:calendar:options:)`` returns every date in the
text, in order, and ``ChronoPT/strippingDates(from:reference:calendar:options:)``
the text without them, which is what a notes app keeps as the title.

## Check what the text gave

A day with no time is set to noon. Before showing an hour, check
``ChronoPT/PartialDate/hasTime``; before showing a year, check
``ChronoPT/PartialDate/knownComponents``:

```swift
let match = ChronoPT.interpret("aniversário 25/09")
match?.start.knownComponents  // [.day, .month], the year came from today
```

## Fix the reference in tests

Relative expressions count from `reference`, which defaults to now, and the
time zone comes from `calendar`. Pass both in tests and on servers so the
answer does not depend on when or where the code runs.
