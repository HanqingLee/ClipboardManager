import XCTest
@testable import ClipboardManagerCore

final class HotkeyConfigTests: XCTestCase {
    func testDefaultIsCommandShiftV() {
        XCTAssertEqual(HotkeyConfig.default.keyCode, 9)
        XCTAssertEqual(HotkeyConfig.default.modifiers, [.command, .shift])
        XCTAssertTrue(HotkeyConfig.default.isValid)
    }

    func testRequiresCommandOptionOrControl() {
        XCTAssertFalse(HotkeyConfig(keyCode: 9, modifiers: []).isValid)
        XCTAssertFalse(HotkeyConfig(keyCode: 9, modifiers: [.shift]).isValid)
        XCTAssertTrue(HotkeyConfig(keyCode: 9, modifiers: [.command]).isValid)
        XCTAssertTrue(HotkeyConfig(keyCode: 9, modifiers: [.option]).isValid)
        XCTAssertTrue(HotkeyConfig(keyCode: 9, modifiers: [.control]).isValid)
        XCTAssertTrue(HotkeyConfig(keyCode: 9, modifiers: [.command, .shift, .option, .control]).isValid)
    }

    func testKeyCodeZeroIsValidBecauseItIsTheAKey() {
        XCTAssertTrue(HotkeyConfig(keyCode: 0, modifiers: [.command]).isValid)
    }

    func testPreferencesRoundTrip() {
        let suite = UserDefaults(suiteName: "HotkeyConfigTests.roundTrip")!
        suite.removePersistentDomain(forName: "HotkeyConfigTests.roundTrip")
        let config = HotkeyConfig(keyCode: 16, modifiers: [.command, .shift])
        config.save(to: suite)
        XCTAssertEqual(HotkeyConfig.load(from: suite), config)
    }

    func testInvalidStoredValueFallsBackToDefault() {
        let suite = UserDefaults(suiteName: "HotkeyConfigTests.invalid")!
        suite.removePersistentDomain(forName: "HotkeyConfigTests.invalid")
        suite.set(9, forKey: "hotkeyKeyCode")
        suite.set(0, forKey: "hotkeyModifiers")
        XCTAssertEqual(HotkeyConfig.load(from: suite), .default)
    }
}