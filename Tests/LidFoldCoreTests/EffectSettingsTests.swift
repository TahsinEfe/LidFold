import XCTest
@testable import LidFoldCore

final class EffectSettingsTests: XCTestCase {
    func testProjectionFollowsTheTwoGeometryToggles() {
        var settings = EffectSettings.default
        XCTAssertEqual(settings.projection, .parallel)

        settings.perspectiveTaper = true
        XCTAssertEqual(settings.projection, .perspective)

        settings.holdContentAngle = false
        XCTAssertEqual(settings.projection, .flat, "Perspective must not survive the angle hold being switched off")
    }

    func testNothingIsDrawnWithBothEffectsOff() {
        var settings = EffectSettings.default
        settings.progressiveBlur = false
        settings.holdContentAngle = false

        XCTAssertFalse(settings.producesVisibleEffect)
    }

    func testInMemoryStoreRoundTripsSettings() {
        let store = InMemorySettingsStore()
        var settings = EffectSettings.default
        settings.settleDelay = 2
        settings.showsAngleReadout = true
        store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }

    func testOverlayIsHiddenBelowTheVisibilityThreshold() {
        let aligned = FoldEffectParameters(foldDelta: 0.001, progressiveBlur: true, projection: .parallel)
        let folded = FoldEffectParameters(foldDelta: 0.05, progressiveBlur: true, projection: .parallel)

        XCTAssertFalse(aligned.isVisible)
        XCTAssertTrue(folded.isVisible)
    }
}
