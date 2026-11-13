import XCTest
@testable import ClipboardManagerCore

final class LanguageResolverTests: XCTestCase {
    func testInAppChoiceWins() {
        XCTAssertEqual(
            LanguageResolver.effective(preferred: "ja", perApp: ["de"], system: ["en"]),
            "ja"
        )
    }

    func testPerAppWinsOverSystem() {
        XCTAssertEqual(
            LanguageResolver.effective(preferred: "", perApp: ["de"], system: ["en"]),
            "de"
        )
    }

    func testSystemFallback() {
        XCTAssertEqual(
            LanguageResolver.effective(preferred: nil, perApp: [], system: ["fr"]),
            "fr"
        )
    }

    func testRightToLeftDetection() {
        XCTAssertTrue(LanguageResolver.isRightToLeft("ar"))
        XCTAssertTrue(LanguageResolver.isRightToLeft("he"))
        XCTAssertFalse(LanguageResolver.isRightToLeft("de"))
        XCTAssertFalse(LanguageResolver.isRightToLeft("zh-Hans"))
    }

    func testFallsBackToEnglish() {
        XCTAssertEqual(
            LanguageResolver.effective(preferred: nil, perApp: nil, system: []),
            "en"
        )
    }
}