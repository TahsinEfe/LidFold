import XCTest
@testable import LidFoldCore

final class AnchorEngineTests: XCTestCase {
    private func engine(at degrees: Double = 110) -> AnchorEngine {
        AnchorEngine(reference: LidAngle(clamping: degrees), now: 0)
    }

    func testHoldsReferenceUntilTheLidHasBeenStillForTheDelay() {
        var engine = engine()
        engine.update(angle: LidAngle(clamping: 80), now: 0.1, autoAnchorEnabled: true)
        engine.update(angle: LidAngle(clamping: 80), now: 0.24, autoAnchorEnabled: true)

        XCTAssertEqual(engine.reference.degrees, 110, accuracy: 0.001)
    }

    func testEasesOntoTheLidOverTheSettleDuration() {
        var engine = engine()
        engine.update(angle: LidAngle(clamping: 80), now: 0.1, autoAnchorEnabled: true)
        engine.update(angle: LidAngle(clamping: 80), now: 0.251, autoAnchorEnabled: true)
        engine.update(angle: LidAngle(clamping: 80), now: 0.351, autoAnchorEnabled: true)

        XCTAssertEqual(engine.reference.degrees, 95, accuracy: 0.01)

        engine.update(angle: LidAngle(clamping: 80), now: 0.46, autoAnchorEnabled: true)
        XCTAssertEqual(engine.reference.degrees, 80, accuracy: 0.001)
        XCTAssertFalse(engine.isSettling)
    }

    func testFurtherMovementInterruptsSettling() {
        var engine = engine()
        engine.update(angle: LidAngle(clamping: 80), now: 0.1, autoAnchorEnabled: true)
        engine.update(angle: LidAngle(clamping: 80), now: 0.251, autoAnchorEnabled: true)
        engine.update(angle: LidAngle(clamping: 80), now: 0.301, autoAnchorEnabled: true)
        let held = engine.reference

        engine.update(angle: LidAngle(clamping: 70), now: 0.32, autoAnchorEnabled: true)
        engine.update(angle: LidAngle(clamping: 70), now: 0.46, autoAnchorEnabled: true)

        XCTAssertEqual(engine.reference.degrees, held.degrees, accuracy: 0.001)
    }

    func testSlowContinuousMovementKeepsRestartingTheDebounce() {
        var engine = engine()
        // One degree every 300 ms never clears the threshold against the previous sample,
        // but does against the last significant angle, so nothing should settle.
        for step in 1...10 {
            engine.update(angle: LidAngle(clamping: 110 - Double(step)), now: Double(step) * 0.3, autoAnchorEnabled: true)
        }
        XCTAssertEqual(engine.reference.degrees, 110, accuracy: 0.001)
    }

    func testSensorJitterDoesNotBlockSettling() {
        var engine = engine()
        engine.update(angle: LidAngle(clamping: 80), now: 0.1, autoAnchorEnabled: true)
        for step in 2...20 {
            let jitter = step.isMultiple(of: 2) ? 0.3 : -0.3
            engine.update(angle: LidAngle(clamping: 80 + jitter), now: Double(step) * 0.1, autoAnchorEnabled: true)
        }
        XCTAssertEqual(engine.reference.degrees, 80, accuracy: 0.4)
    }

    func testDisabledAutoAnchorHoldsTheReferenceIndefinitely() {
        var engine = engine()
        engine.update(angle: LidAngle(clamping: 70), now: 1, autoAnchorEnabled: false)
        engine.update(angle: LidAngle(clamping: 70), now: 10, autoAnchorEnabled: false)

        XCTAssertEqual(engine.reference.degrees, 110, accuracy: 0.001)
    }

    func testManualAnchorResetsTheReferenceImmediately() {
        var engine = engine()
        engine.anchor(to: LidAngle(clamping: 70), now: 11)
        engine.update(angle: LidAngle(clamping: 60), now: 11.1, autoAnchorEnabled: true)

        XCTAssertEqual(engine.reference.degrees, 70, accuracy: 0.001)
    }

    func testFoldDeltaIsTheSignedDifferenceInRadians() {
        let engine = engine(at: 110)
        let delta = engine.foldDelta(for: LidAngle(clamping: 80))

        XCTAssertEqual(delta, 30 * .pi / 180, accuracy: 0.0001)
    }
}
