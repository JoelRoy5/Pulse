import XCTest
@testable import PulseShared

final class AnalyticsQueueTests: XCTestCase {
    private func d(_ s: String) -> Data { Data(s.utf8) }
    func testBatchPeekDoesNotRemove() {
        let q = AnalyticsQueue(capacity: 100, batchSize: 2)
        q.enqueue(d("a")); q.enqueue(d("b")); q.enqueue(d("c"))
        XCTAssertEqual(q.makeBatch(), [d("a"), d("b")])
        XCTAssertEqual(q.count, 3) // peek only
        q.removeBatch(count: 2)
        XCTAssertEqual(q.count, 1)
        XCTAssertEqual(q.makeBatch(), [d("c")])
    }
    func testCapacityDropsOldest() {
        let q = AnalyticsQueue(capacity: 2, batchSize: 10)
        q.enqueue(d("a")); q.enqueue(d("b")); q.enqueue(d("c"))
        XCTAssertEqual(q.count, 2)
        XCTAssertEqual(q.makeBatch(), [d("b"), d("c")]) // "a" dropped
    }
    func testPersistAndLoadRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aq-\(UUID()).json")
        let q = AnalyticsQueue(capacity: 100, batchSize: 5)
        q.enqueue(d("x")); q.enqueue(d("y"))
        q.persist(to: url)
        let loaded = AnalyticsQueue.load(from: url, capacity: 100, batchSize: 5)
        XCTAssertEqual(loaded.makeBatch(), [d("x"), d("y")])
        try? FileManager.default.removeItem(at: url)
    }
    func testClearEmpties() {
        let q = AnalyticsQueue(); q.enqueue(d("a")); q.clear()
        XCTAssertEqual(q.count, 0)
    }
}
