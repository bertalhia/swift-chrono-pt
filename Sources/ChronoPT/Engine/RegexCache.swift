import Foundation

/// Compiled regexes, kept per thread.
///
/// Building a regex costs about 25 times what matching it does, and the rules
/// use more than a dozen on every call. `Regex` is not `Sendable`, so one
/// instance is never shared between threads: each thread keeps the ones it
/// built in its own storage, and nothing crosses from one thread to another.
enum RegexCache {
    /// The key is where the call sits, so keep one call per computed property.
    /// Two regexes sharing a key would evict each other, and if their outputs
    /// differed the cast below would fail every time: the regex would be
    /// rebuilt on every call, a 25-fold slowdown with no error.
    static func regex<Output>(
        file: String = #fileID,
        name: String = #function,
        line: Int = #line,
        _ build: () -> Regex<Output>
    ) -> Regex<Output> {
        let storage = Thread.current.threadDictionary
        let key = "ChronoPT.RegexCache \(file):\(line) \(name)"
        if let cached = storage[key] as? Regex<Output> { return cached }
        let regex = build()
        storage[key] = regex
        return regex
    }
}
