import XCTest
@testable import ClipboardManagerCore

final class DominantColorTests: XCTestCase {
    private func solid(_ r: UInt8, _ g: UInt8, _ b: UInt8, count: Int, alpha: UInt8 = 255) -> [UInt8] {
        Array(repeating: [r, g, b, alpha], count: count).flatMap { $0 }
    }

    func testExtractsSaturatedColor() {
        let fallback = AppColor(red: 0.5, green: 0.5, blue: 0.5)
        let c = DominantColor.extract(fromRGBA8: solid(20, 200, 60, count: 64), fallback: fallback)
        XCTAssertGreaterThan(c.green, c.red)
        XCTAssertGreaterThan(c.green, c.blue)
        XCTAssertGreaterThan(c.green, 0.5)
    }

    func testWhiteImageFallsBack() {
        let fallback = AppColor(red: 0.1, green: 0.2, blue: 0.3)
        let c = DominantColor.extract(fromRGBA8: solid(255, 255, 255, count: 64), fallback: fallback)
        XCTAssertEqual(c, fallback)
    }

    func testNearBlackFallsBack() {
        let fallback = AppColor(red: 0.4, green: 0.4, blue: 0.4)
        let c = DominantColor.extract(fromRGBA8: solid(3, 3, 3, count: 32), fallback: fallback)
        XCTAssertEqual(c, fallback)
    }

    func testTransparentPixelsIgnored() {
        let fallback = AppColor(red: 0, green: 0, blue: 0)
        let c = DominantColor.extract(fromRGBA8: solid(0, 128, 255, count: 16, alpha: 0), fallback: fallback)
        XCTAssertEqual(c, fallback)
    }

    func testEmptyInputFallsBack() {
        let fallback = AppColor(red: 0.9, green: 0.1, blue: 0.1)
        XCTAssertEqual(DominantColor.extract(fromRGBA8: [], fallback: fallback), fallback)
    }

    func testFallbackIsDeterministicAndVaries() {
        let a1 = DominantColor.fallback(for: "Terminal")
        let a2 = DominantColor.fallback(for: "Terminal")
        XCTAssertEqual(a1, a2)
        let names = ["Terminal", "Safari", "Xcode", "WeChat", "Notes"]
        let colors = names.map { DominantColor.fallback(for: $0) }
        XCTAssertGreaterThan(Set(colors.map { "\($0.red),\($0.green),\($0.blue)" }).count, 1)
    }

    func testBoostIncreasesSaturation() {
        let dull = AppColor(red: 0.5, green: 0.5, blue: 0.55)
        let boosted = DominantColor.boost(dull)
        let before = dull.blue - dull.red
        let after = boosted.blue - boosted.red
        XCTAssertGreaterThan(after, before)

        // 完全灰 → boost 后应产生可见饱和度
        let gray = AppColor(red: 0.5, green: 0.5, blue: 0.5)
        let tinted = DominantColor.boost(gray)
        XCTAssertGreaterThan(tinted.red - tinted.green, 0.0)
    }
}
