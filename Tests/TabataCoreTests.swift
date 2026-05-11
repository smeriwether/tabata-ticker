import XCTest

#if canImport(TabataCore)
@testable import TabataCore
#endif

final class TabataCoreTests: XCTestCase {
    func testClassicWorkoutStartsWithWork() {
        let now = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: now)

        XCTAssertEqual(engine.state.phase, .work)
        XCTAssertEqual(engine.state.round, 1)
        XCTAssertEqual(engine.state.remaining(at: now), 20)
    }

    func testTransitionsFromWorkToRest() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: start)
        let state = engine.tick(now: start.addingTimeInterval(20))

        XCTAssertEqual(state.phase, .rest)
        XCTAssertEqual(state.round, 1)
        XCTAssertEqual(state.remaining(at: start.addingTimeInterval(20)), 10)
    }

    func testTransitionsFromRestToNextRound() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: start)
        let state = engine.tick(now: start.addingTimeInterval(30))

        XCTAssertEqual(state.phase, .work)
        XCTAssertEqual(state.round, 2)
        XCTAssertEqual(state.remaining(at: start.addingTimeInterval(30)), 20)
    }

    func testCompletesAfterEightRounds() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: start)
        let state = engine.tick(now: start.addingTimeInterval(240))

        XCTAssertEqual(state.phase, .complete)
        XCTAssertFalse(state.isRunning)
        XCTAssertEqual(state.remaining(at: start.addingTimeInterval(240)), 0)
    }

    func testPauseAndResumePreserveRemainingTime() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: start)
        engine.pause(now: start.addingTimeInterval(7))

        XCTAssertFalse(engine.state.isRunning)
        XCTAssertEqual(engine.state.remaining(at: start.addingTimeInterval(50)), 13)

        engine.resume(now: start.addingTimeInterval(100))

        XCTAssertTrue(engine.state.isRunning)
        XCTAssertEqual(engine.state.remaining(at: start.addingTimeInterval(105)), 8)
    }

    func testCountdownCuePolicy() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: start)

        XCTAssertNil(TabataCuePolicy.countdownCue(in: engine.state, now: start.addingTimeInterval(14)))
        XCTAssertEqual(TabataCuePolicy.countdownCue(in: engine.state, now: start.addingTimeInterval(15))?.second, 5)
        XCTAssertEqual(TabataCuePolicy.countdownCue(in: engine.state, now: start.addingTimeInterval(19.2))?.second, 1)

        let restState = engine.tick(now: start.addingTimeInterval(20))

        XCTAssertNil(TabataCuePolicy.countdownCue(in: restState, now: start.addingTimeInterval(26)))
        XCTAssertEqual(TabataCuePolicy.countdownCue(in: restState, now: start.addingTimeInterval(27))?.second, 3)
    }

    func testSoundsToggleSuppressesCues() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: start)
        engine.setSoundsEnabled(false)

        XCTAssertNil(TabataCuePolicy.countdownCue(in: engine.state, now: start.addingTimeInterval(15)))
        XCTAssertFalse(TabataCuePolicy.needsTransitionCue(from: engine.state, to: engine.tick(now: start.addingTimeInterval(20))))
    }

    func testResetPreservesSoundsSetting() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.setSoundsEnabled(false)
        engine.start(now: start)
        engine.reset()

        XCTAssertFalse(engine.state.soundsEnabled)
        XCTAssertEqual(engine.state.phase, .idle)
    }
}
