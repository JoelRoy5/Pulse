import Foundation

/// A queued event payload (ready for transmission).
public struct QueuedEvent: Codable, Sendable, Equatable {
    /// The JSON-encoded event payload as Data.
    public let json: Data

    public init(json: Data) {
        self.json = json
    }
}

/// A pure, thread-safe analytics event queue with capacity eviction, batching, and disk persistence.
public final class AnalyticsQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [Data] = []
    private let capacity: Int
    private let batchSize: Int

    /// Initializes the queue with optional capacity and batch size.
    ///
    /// - Parameters:
    ///   - capacity: Maximum number of events to store. Defaults to 500.
    ///   - batchSize: Maximum number of events to return in `makeBatch()`. Defaults to 20.
    public init(capacity: Int = 500, batchSize: Int = 20) {
        self.capacity = capacity
        self.batchSize = batchSize
    }

    /// Adds an event to the queue. If the queue exceeds capacity, the oldest event is dropped.
    ///
    /// - Parameter payload: The pre-serialized event data.
    public func enqueue(_ payload: Data) {
        lock.lock()
        defer { lock.unlock() }

        events.append(payload)
        if events.count > capacity {
            events.removeFirst()
        }
    }

    /// Returns up to `batchSize` oldest events without removing them.
    ///
    /// - Returns: An array of up to `batchSize` events, in FIFO order.
    public func makeBatch() -> [Data] {
        lock.lock()
        defer { lock.unlock() }

        let count = min(batchSize, events.count)
        return Array(events.prefix(count))
    }

    /// Removes the first `count` events from the queue.
    ///
    /// - Parameter count: The number of events to remove.
    public func removeBatch(count: Int) {
        lock.lock()
        defer { lock.unlock() }

        let toRemove = min(count, events.count)
        events.removeFirst(toRemove)
    }

    /// Re-queues a batch at the front (no-op in the current implementation; included for API clarity).
    ///
    /// - Parameter batch: The batch to re-queue.
    public func requeueFront(_ batch: [Data]) {
        // No-op: since makeBatch() only peeks, failed sends are automatically retried.
    }

    /// The current number of events in the queue.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return events.count
    }

    /// Persists the queue to a JSON file (base64-encoded Data array).
    ///
    /// - Parameter url: The file URL to write to.
    public func persist(to url: URL) {
        lock.lock()
        defer { lock.unlock() }

        let encoded = events.map { $0.base64EncodedString() }
        if let data = try? JSONSerialization.data(withJSONObject: encoded, options: []) {
            try? data.write(to: url)
        }
    }

    /// Loads the queue from a JSON file. Swallows any errors and returns an empty queue on failure.
    ///
    /// - Parameters:
    ///   - url: The file URL to read from.
    ///   - capacity: The capacity for the new queue.
    ///   - batchSize: The batch size for the new queue.
    /// - Returns: A new AnalyticsQueue with persisted events, or an empty queue if loading fails.
    public static func load(from url: URL, capacity: Int, batchSize: Int) -> AnalyticsQueue {
        let queue = AnalyticsQueue(capacity: capacity, batchSize: batchSize)

        guard let data = try? Data(contentsOf: url) else { return queue }
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [String] else { return queue }

        let decoded = jsonArray.compactMap { Data(base64Encoded: $0) }
        queue.lock.lock()
        defer { queue.lock.unlock() }
        queue.events = decoded

        return queue
    }

    /// Clears all events from the queue.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        events.removeAll()
    }
}
