import XCTest
@testable import LidFoldCore

final class EffectIntensityTests: XCTestCase {
    func testClosingIsAmplifiedAndOpeningIsNot() {
        let closing = 0.5
        let opening = -0.5

        XCTAssertEqual(EffectIntensity.strong.shape(closing), 0.5 * 1.8, accuracy: 0.0001)
        XCTAssertEqual(EffectIntensity.strong.shape(opening), -0.5, accuracy: 0.0001)
    }

    func testSubtleLeavesTheFoldUntouched() {
        XCTAssertEqual(EffectIntensity.subtle.shape(0.4), 0.4, accuracy: 0.0001)
    }

    func testGainAndBlurRiseTogetherAcrossTheLevels() {
        let ordered = EffectIntensity.allCases
        for (lower, higher) in zip(ordered, ordered.dropFirst()) {
            XCTAssertLessThan(lower.closingGain, higher.closingGain)
            XCTAssertLessThan(lower.blurScale, higher.blurScale)
        }
    }

    func testRawValuesSurviveARoundTrip() {
        for intensity in EffectIntensity.allCases {
            XCTAssertEqual(EffectIntensity(rawValue: intensity.rawValue), intensity)
        }
    }
}
