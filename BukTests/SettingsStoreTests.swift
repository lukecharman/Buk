import XCTest
@testable import Buk

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaults() {
        // We don't share global UserDefaults between test runs in a clean way, but we
        // can at least assert the static configuration is sensible.
        XCTAssertTrue(SettingsStore.allowedSkipValues.contains(15))
        XCTAssertTrue(SettingsStore.allowedSkipValues.contains(30))
        XCTAssertTrue(SettingsStore.allowedRates.contains(1.0))
        XCTAssertTrue(SettingsStore.allowedRates.contains(2.0))
        XCTAssertEqual(SettingsStore.allowedRates.first, 0.5)
        XCTAssertTrue(SettingsStore.allowedSleepTimers.contains(0))
    }
}
