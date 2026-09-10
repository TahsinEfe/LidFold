import XCTest
@testable import LidFoldCore

final class ExponentialSmootherTests: XCTestCase {
    func testCoversAboutSixtyThreePercentInOneTimeConstant() {
        var smoother = ExponentialSmoother(value: 0, timeConstant: 0.1)
        smoother.step(towards: 1, deltaTime: 0.1)

        XCTAssertEqual(smoother.value, 0.632, accuracy: 0.005)
    }

    func testResultIsIndependentOfTheStepCount() {
        var coarse = ExponentialSmoother(value: 0, timeConstant: 0.08)
        var fine = ExponentialSmoother(value: 0, timeConstant: 0.08)

        coarse.step(towards: 1, deltaTime: 0.1)
        for _ in 0..<10 { fine.step(towards: 1, deltaTime: 0.01) }

        XCTAssertEqual(coarse.value, fine.value, accuracy: 0.001)
    }

    func testZeroDeltaTimeSnapsRatherThanStalling() {
        var smoother = ExponentialSmoother(value: 0, timeConstant: 0.08)
        smoother.step(towards: 1, deltaTime: 0)

        XCTAssertEqual(smoother.value, 1)
    }

    func testResetSkipsTheRamp() {
        var smoother = ExponentialSmoother(value: 0.5)
        smoother.reset()

        XCTAssertEqual(smoother.value, 0)
    }
}
