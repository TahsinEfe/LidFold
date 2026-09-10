import XCTest
@testable import LidFoldCore

final class LidAngleReportTests: XCTestCase {
    func testDecodesLittleEndianAngleFromBytesOneAndTwo() {
        let report: [UInt8] = [0x01, 0x69, 0x00, 0, 0, 0, 0, 0]
        XCTAssertEqual(LidAngleReport.decode(report, length: 8)?.degrees, 105)
    }

    func testDecodesAngleWithHighByteSet() {
        let report: [UInt8] = [0x01, 0x2C, 0x01, 0, 0, 0, 0, 0]  // 300, out of range
        XCTAssertNil(LidAngleReport.decode(report, length: 8))
    }

    func testRejectsShortReports() {
        let report: [UInt8] = [0x01, 0x69, 0x00, 0, 0, 0, 0, 0]
        XCTAssertNil(LidAngleReport.decode(report, length: 2))
        XCTAssertNil(LidAngleReport.decode([0x01], length: 3))
    }
}
