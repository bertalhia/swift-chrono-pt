# Contributing

The goal is the most reliable natural-language date parser for Brazilian
Portuguese in Swift. Reliability comes before coverage: every new case comes
with tests, and no existing case may break.

Open work is tracked in [issues](https://github.com/bertalhia/swift-chrono-pt/issues).
Bug reports are most useful with the exact text, the reference date and time
zone, the result you got and the result you expected.

## Rules

- Deterministic: no `NSDataDetector`, language model or network. Every result
  comes from `reference` and `calendar`: the same text with the same reference
  always gives the same answer.
- New cases fit the structure. A new case is a new rule in `DayRules`, a
  new row in the `TimeRules` table, or a new merge step in `ChronoPT.swift`.
  If a case needs an exception inside another rule, change the structure
  instead.
- Every case has a test, run against the fixed reference date in
  `Tests/ChronoPTTests/Support.swift` (Monday, 21 September 2026, 10:00, São
  Paulo). Negative cases too: "segunda via do boleto" is not a date.
- The text is read once. `TextSource` removes accents, case and
  punctuation while keeping one character for each character of the original,
  so every position a rule finds maps back to the text the user wrote.
- Swift 6 with strict concurrency. `Regex` is not `Sendable`, so regexes
  live in computed properties that go through `RegexCache`, not in static
  constants.
- Swift Testing, not XCTest.
- English for code, comments, documentation, test names and commit
  messages. Input examples stay in Portuguese.

## Layout

| File | What it does |
|---|---|
| `ChronoPT.swift` | The entry points, `parse` and `interpret` |
| `API/` | The public types: `Match`, `PartialDate`, `Options`, `Parser`, `Recurrence`, `TimeOfDay`, and `strippingDates` |
| `Engine/TextSource.swift` | Normalized text with a position map, word lookups, and the words that open and close a range |
| `Engine/Piece.swift` | A match with its position, and overlap removal |
| `Engine/SpokenNumber.swift` | Spelled-out numbers |
| `Engine/RegexCache.swift` | Compiled regexes, shared through a pool |
| `Engine/Context.swift` | Joins a day with a time and builds the result |
| `Day/DayRules.swift` | Finds the days in the text, including ranges |
| `Day/DayValue.swift` | What a day can be, and which components the text fixed |
| `Day/DayPatterns.swift` | Day regexes and word tables |
| `Day/DayResolution.swift` | From a day to a date, holidays included |
| `Time/TimeRules.swift` | Finds the time pieces |
| `Time/TimePatterns.swift` | Clock regexes and the duration guard |
| `Time/PeriodTable.swift` | Parts of the day and moments, with the hour each one means |
| `Time/TimeResolution.swift` | From the pieces to a clock time, ranges included |

## Running the tests

```bash
swift test
```

## Versioning

Semantic versioning through git tags, which Swift Package Manager reads. From
1.0.0, the Stability section of the README says what each kind of release may
change: a new phrase is a minor release, a changed or removed public symbol a
major one.

## Pull requests

Keep each pull request to one topic, with tests for every case it adds or
changes, and make sure `swift test` passes.
