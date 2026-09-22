import Foundation

/// Compiled regexes, shared through a pool.
///
/// Building a regex costs about 25 times what matching it does, and a parse
/// uses dozens. `Regex` is not `Sendable`, so a compiled set is never used by
/// two threads at once: each parse takes a set from the pool, uses it on its
/// own thread, and gives it back. The pool holds as many sets as parses ever
/// ran at the same time, so a new thread reuses what an earlier one compiled
/// instead of paying for it again, and a thread that ends leaves nothing
/// behind.
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
        let compiled = current
        let key = "\(file):\(line) \(name)"
        if let cached = compiled.regexes[key] as? Regex<Output> { return cached }
        let regex = build()
        compiled.regexes[key] = regex
        return regex
    }

    /// Runs `body` with a compiled set of its own from the pool.
    static func using<Result>(_ body: () throws -> Result) rethrows -> Result {
        let storage = Thread.current.threadDictionary
        // Already holding one: a parse inside a parse.
        if storage[activeKey] != nil { return try body() }
        let compiled = pool.take()
        storage[activeKey] = compiled
        defer {
            storage[activeKey] = nil
            pool.give(compiled)
        }
        return try body()
    }

    /// The set this thread holds, or, outside `using`, one kept for the
    /// thread, as the rules run directly in tests.
    private static var current: Compiled {
        let storage = Thread.current.threadDictionary
        if let compiled = storage[activeKey] as? Compiled { return compiled }
        if let compiled = storage[fallbackKey] as? Compiled { return compiled }
        let compiled = Compiled()
        storage[fallbackKey] = compiled
        return compiled
    }

    /// How many sets wait in the pool.
    static var idleCount: Int { pool.count }

    /// Whether this thread holds on to a set of its own.
    static var threadKeepsSet: Bool {
        let storage = Thread.current.threadDictionary
        return storage[activeKey] != nil || storage[fallbackKey] != nil
    }

    private static let activeKey = "ChronoPT.RegexCache.active"
    private static let fallbackKey = "ChronoPT.RegexCache.thread"
    private static let pool = Pool()

    /// One set of compiled regexes, by where they are declared.
    final class Compiled {
        var regexes: [String: Any] = [:]
    }

    /// The sets no parse is using.
    ///
    /// `@unchecked Sendable`: it holds `Compiled` sets, whose regexes are not
    /// `Sendable`. Every access goes through the lock, and a set leaves the
    /// pool for exactly one thread until it comes back, so no set is ever
    /// touched by two threads at once; the lock orders each hand-over.
    private final class Pool: @unchecked Sendable {
        private let lock = NSLock()
        private var idle: [Compiled] = []

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return idle.count
        }

        func take() -> Compiled {
            lock.lock()
            defer { lock.unlock() }
            return idle.popLast() ?? Compiled()
        }

        func give(_ compiled: Compiled) {
            lock.lock()
            defer { lock.unlock() }
            idle.append(compiled)
        }
    }
}
