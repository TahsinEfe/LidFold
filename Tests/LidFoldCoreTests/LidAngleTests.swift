import XCTest
@testable import LidFoldCore

final class LidAngleTests: XCTestCase {
    func testRejectsReadingsOutsideThePhysicalRange() {
        XCTAssertNil(LidAngle(degrees: -1))
        XCTAssertNil(LidAngle(degrees: 181))
        XCTAssertNil(LidAngle(degrees: .nan))
        XCTAssertNil(LidAngle(degrees: .infinity))
        XCTAssertNotNil(LidAngle(degrees: 0))
        XCTAssertNotNil(LidAngle(degrees: 180))
    }

    func testClampingPullsValuesIntoRangeAndSurvivesNaN() {
        XCTAssertEqual(LidAngle(clamping: -20).degrees, 0)
        XCTAssertEqual(LidAngle(clamping: 400).degrees, 180)
        XCTAssertEqual(LidAngle(clamping: .nan).degrees, LidAngle.neutral.degrees)
    }

    func testOffsetStaysInRange() {
        XCTAssertEqual(LidAngle(clamping: 10).offset(by: -35).degrees, 0)
        XCTAssertEqual(LidAngle(clamping: 100).offset(by: 20).degrees, 120)
    }

    func testReadoutRoundsToWholeDegrees() {
        XCTAssertEqual(LidAngle(clamping: 104.6).readout, "105°")
    }

    func testSeparationIsUnsigned() {
        XCTAssertEqual(LidAngle(clamping: 100).separation(from: LidAngle(clamping: 130)), 30, accuracy: 0.001)
        XCTAssertEqual(LidAngle(clamping: 130).separation(from: LidAngle(clamping: 100)), 30, accuracy: 0.001)
    }
}
