import XCTest
@testable import ClipboardManagerCore

final class ClipboardItemTests: XCTestCase {
    func testMakeHashIsStableAndKindSensitive() {
        let a = ClipboardItem.makeHash(kind: .text, text: "hi", fileURL: nil, imageBytes: nil)
        let b = ClipboardItem.makeHash(kind: .text, text: "hi", fileURL: nil, imageBytes: nil)
        let c = ClipboardItem.makeHash(kind: .file, text: "hi", fileURL: nil, imageBytes: nil)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCodableRoundTrip() throws {
        let item = ClipboardItem(kind: .text, text: "hello",
                                 sourceAppName: "Safari", contentHash: "abc")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(item, decoded)
    }

    func testTextPreviewTrimsAndTruncates() {
        let item = ClipboardItem(kind: .text,
                                 text: "  " + String(repeating: "x", count: 200) + "  ",
                                 contentHash: "h")
        XCTAssertTrue(item.preview.hasPrefix("xxx"))
        XCTAssertEqual(item.preview.count, 120)
    }
}
