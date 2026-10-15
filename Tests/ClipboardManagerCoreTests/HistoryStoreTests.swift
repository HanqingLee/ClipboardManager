import XCTest
@testable import ClipboardManagerCore

final class HistoryStoreTests: XCTestCase {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func testRecordsNewestFirst() {
        let store = HistoryStore(capacity: 100, directory: tempDir())
        XCTAssertTrue(store.record(.init(kind: .text, text: "one")))
        XCTAssertTrue(store.record(.init(kind: .text, text: "two")))
        XCTAssertEqual(store.items.first?.text, "two")
        XCTAssertEqual(store.items.last?.text, "one")
    }

    func testDeduplicatesConsecutive() {
        let store = HistoryStore(capacity: 100, directory: tempDir())
        XCTAssertTrue(store.record(.init(kind: .text, text: "same")))
        XCTAssertFalse(store.record(.init(kind: .text, text: "same")))
        XCTAssertEqual(store.items.count, 1)
    }

    func testTrimsToCapacity() {
        let store = HistoryStore(capacity: 3, directory: tempDir())
        for i in 1...5 { _ = store.record(.init(kind: .text, text: "item\(i)")) }
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(store.items.map(\.text), ["item5", "item4", "item3"])
    }

    func testEmptyTextRejected() {
        let store = HistoryStore(capacity: 10, directory: tempDir())
        XCTAssertFalse(store.record(.init(kind: .text, text: "")))
        XCTAssertTrue(store.items.isEmpty)
    }

    func testPersistenceRoundTrip() {
        let dir = tempDir()
        let store = HistoryStore(capacity: 10, directory: dir)
        _ = store.record(.init(kind: .text, text: "persist me"))
        store.save()

        let reloaded = HistoryStore(capacity: 10, directory: dir)
        reloaded.load()
        XCTAssertEqual(reloaded.items.first?.text, "persist me")
    }

    func testPromoteMovesItemToFront() {
        let store = HistoryStore(capacity: 100, directory: tempDir())
        _ = store.record(.init(kind: .text, text: "one"))
        _ = store.record(.init(kind: .text, text: "two"))
        _ = store.record(.init(kind: .text, text: "three"))
        guard let target = store.items.first(where: { $0.text == "one" }) else {
            return XCTFail("expected 'one' in history")
        }

        XCTAssertTrue(store.promote(id: target.id))

        XCTAssertEqual(store.items.map(\.text), ["one", "three", "two"])
    }

    func testPromoteUpdatesTimestamp() {
        let store = HistoryStore(capacity: 100, directory: tempDir())
        _ = store.record(.init(kind: .text, text: "one"))
        guard let target = store.items.first else {
            return XCTFail("expected an item")
        }
        let stamp = Date(timeIntervalSince1970: 1_234_567)

        XCTAssertTrue(store.promote(id: target.id, at: stamp))

        XCTAssertEqual(store.items.first?.createdAt, stamp)
    }

    func testPromoteAlreadyFirstKeepsOrderAndBumpsTime() {
        let store = HistoryStore(capacity: 100, directory: tempDir())
        _ = store.record(.init(kind: .text, text: "one"))
        _ = store.record(.init(kind: .text, text: "two"))
        guard let first = store.items.first else {
            return XCTFail("expected an item")
        }
        let stamp = Date(timeIntervalSince1970: 9_999_999)

        XCTAssertTrue(store.promote(id: first.id, at: stamp))

        XCTAssertEqual(store.items.map(\.text), ["two", "one"])
        XCTAssertEqual(store.items.first?.createdAt, stamp)
    }

    func testPromoteUnknownIDReturnsFalseAndLeavesHistoryUnchanged() {
        let store = HistoryStore(capacity: 100, directory: tempDir())
        _ = store.record(.init(kind: .text, text: "one"))
        _ = store.record(.init(kind: .text, text: "two"))
        let before = store.items.map(\.id)

        XCTAssertFalse(store.promote(id: UUID()))

        XCTAssertEqual(store.items.map(\.id), before)
    }

    func testPromotePersistsAcrossReload() {
        let dir = tempDir()
        let store = HistoryStore(capacity: 100, directory: dir)
        _ = store.record(.init(kind: .text, text: "one"))
        _ = store.record(.init(kind: .text, text: "two"))
        guard let target = store.items.first(where: { $0.text == "one" }) else {
            return XCTFail("expected 'one' in history")
        }
        XCTAssertTrue(store.promote(id: target.id))
        store.save()

        let reloaded = HistoryStore(capacity: 100, directory: dir)
        reloaded.load()

        XCTAssertEqual(reloaded.items.map(\.text), ["one", "two"])
    }

    func testImagePersistedAndLoaded() {
        let store = HistoryStore(capacity: 10, directory: tempDir())
        let bytes = Data([0x89, 0x50, 0x4E, 0x47])
        XCTAssertTrue(store.record(.init(kind: .image, imageData: bytes)))
        guard let ref = store.items.first?.imageRef else {
            return XCTFail("expected imageRef")
        }
        XCTAssertEqual(store.imageData(forRef: ref), bytes)
    }
}
