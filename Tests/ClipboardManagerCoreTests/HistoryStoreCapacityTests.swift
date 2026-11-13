import XCTest
@testable import ClipboardManagerCore

final class HistoryStoreCapacityTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSetCapacityTrimsAndPersists() {
        let store = HistoryStore(capacity: 100, directory: directory)
        for index in 0..<60 {
            XCTAssertTrue(store.record(CapturedContent(kind: .text, text: "item-\(index)")))
        }
        XCTAssertEqual(store.items.count, 60)

        store.setCapacity(50)

        XCTAssertEqual(store.capacity, 50)
        XCTAssertEqual(store.items.count, 50)
        XCTAssertEqual(store.items.first?.text, "item-59")

        let reloaded = HistoryStore(capacity: 50, directory: directory)
        reloaded.load()
        XCTAssertEqual(reloaded.items.count, 50)
        XCTAssertEqual(reloaded.items.first?.text, "item-59")
    }

    func testSetCapacityDeletesTrimmedImages() throws {
        let store = HistoryStore(capacity: 10, directory: directory)
        let image = Data([0x89, 0x50, 0x4E, 0x47])
        XCTAssertTrue(store.record(CapturedContent(kind: .image, imageData: image)))
        XCTAssertTrue(store.record(CapturedContent(kind: .text, text: "newer-1")))
        XCTAssertTrue(store.record(CapturedContent(kind: .text, text: "newer-2")))

        let imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)
        let filesBefore = try FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path)
        XCTAssertEqual(filesBefore.count, 1)

        store.setCapacity(1)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.text, "newer-2")
        let filesAfter = try FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path)
        XCTAssertTrue(filesAfter.isEmpty)
    }
}