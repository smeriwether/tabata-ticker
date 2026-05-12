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

    func testToggleRunningStartsPausesResumesAndRestartsCompleteWorkout() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.toggleRunning(now: start)

        XCTAssertEqual(engine.state.phase, .work)
        XCTAssertTrue(engine.state.isRunning)

        engine.toggleRunning(now: start.addingTimeInterval(3))

        XCTAssertFalse(engine.state.isRunning)
        XCTAssertEqual(engine.state.remaining(at: start.addingTimeInterval(100)), 17)

        engine.toggleRunning(now: start.addingTimeInterval(30))

        XCTAssertTrue(engine.state.isRunning)
        XCTAssertEqual(engine.state.remaining(at: start.addingTimeInterval(30)), 17)

        _ = engine.tick(now: start.addingTimeInterval(270))

        XCTAssertEqual(engine.state.phase, .complete)

        engine.toggleRunning(now: start.addingTimeInterval(300))

        XCTAssertEqual(engine.state.phase, .work)
        XCTAssertEqual(engine.state.round, 1)
        XCTAssertTrue(engine.state.isRunning)
    }

    func testLongTimeJumpLandsInCorrectPhase() {
        let start = Date(timeIntervalSince1970: 100)
        let config = TabataConfig(rounds: 3, workDuration: 20, restDuration: 10)
        var engine = TabataEngine(state: .idle(config: config))

        engine.start(now: start)
        let state = engine.tick(now: start.addingTimeInterval(65))

        XCTAssertEqual(state.phase, .work)
        XCTAssertEqual(state.round, 3)
        XCTAssertEqual(state.remaining(at: start.addingTimeInterval(65)), 15)
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

    func testTransitionCuePolicySuppressesStartAndUnchangedState() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()
        let idleState = engine.state

        engine.start(now: start)
        let workState = engine.state

        XCTAssertFalse(TabataCuePolicy.needsTransitionCue(from: idleState, to: workState))
        XCTAssertFalse(TabataCuePolicy.needsTransitionCue(from: workState, to: workState))

        let restState = engine.tick(now: start.addingTimeInterval(20))

        XCTAssertTrue(TabataCuePolicy.needsTransitionCue(from: workState, to: restState))

        var mutedRestState = restState
        mutedRestState.soundsEnabled = false
        mutedRestState.hapticsEnabled = false

        XCTAssertFalse(TabataCuePolicy.needsTransitionCue(from: workState, to: mutedRestState))
    }

    func testCueSettingsSuppressCuesWhenBothAreOff() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: start)
        engine.setSoundsEnabled(false)
        engine.setHapticsEnabled(false)

        XCTAssertNil(TabataCuePolicy.countdownCue(in: engine.state, now: start.addingTimeInterval(15)))
        XCTAssertFalse(TabataCuePolicy.needsTransitionCue(from: engine.state, to: engine.tick(now: start.addingTimeInterval(20))))
    }

    func testHapticOnlyCuesStillRun() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: start)
        engine.setSoundsEnabled(false)

        XCTAssertEqual(TabataCuePolicy.countdownCue(in: engine.state, now: start.addingTimeInterval(15))?.second, 5)
    }

    func testResetPreservesCueSettings() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.setSoundsEnabled(false)
        engine.setHapticsEnabled(false)
        engine.start(now: start)
        engine.reset()

        XCTAssertFalse(engine.state.soundsEnabled)
        XCTAssertFalse(engine.state.hapticsEnabled)
        XCTAssertEqual(engine.state.phase, .idle)
    }

    func testPresetNameUsesWorkRestAndRounds() {
        let config = TabataConfig.preset(workSeconds: 45, restSeconds: 15, rounds: 6)

        XCTAssertEqual(config.presetName, "45/15/6")
    }

    func testPresetCatalogDefaultsToClassicAndSelectedPreset() {
        let custom = TabataPreset(
            id: "custom",
            config: TabataConfig.preset(workSeconds: 40, restSeconds: 20, rounds: 5),
            isDefault: false
        )
        let catalog = TabataPresetCatalog(customPresets: [custom], selectedID: "custom")

        XCTAssertEqual(catalog.presets.map(\.name), ["20/10/8", "40/20/5"])
        XCTAssertEqual(catalog.selectedPreset, custom)
    }

    func testPresetCatalogProtectsDefaultPreset() {
        var catalog = TabataPresetCatalog()

        XCTAssertFalse(catalog.deleteUserPreset(id: TabataPreset.defaultID))
        XCTAssertFalse(catalog.updateUserPreset(id: TabataPreset.defaultID, config: TabataConfig.preset(workSeconds: 30, restSeconds: 15, rounds: 4)))
        XCTAssertEqual(catalog.selectedPreset, .classic)
    }

    func testPresetCatalogAllowsDuplicatesAndCapsAtFourTotalPresets() {
        var catalog = TabataPresetCatalog()

        XCTAssertNotNil(catalog.addUserPreset(config: TabataConfig.preset(workSeconds: 30, restSeconds: 15, rounds: 4), id: "one"))
        XCTAssertNotNil(catalog.addUserPreset(config: TabataConfig.preset(workSeconds: 30, restSeconds: 15, rounds: 4), id: "duplicate"))
        XCTAssertNotNil(catalog.addUserPreset(config: TabataConfig.preset(workSeconds: 45, restSeconds: 15, rounds: 5), id: "two"))
        XCTAssertNil(catalog.addUserPreset(config: TabataConfig.preset(workSeconds: 60, restSeconds: 30, rounds: 6), id: "three"))

        XCTAssertEqual(catalog.presets.count, 4)
        XCTAssertEqual(catalog.userPresets.map(\.name), ["30/15/4", "30/15/4", "45/15/5"])
        XCTAssertFalse(catalog.canCreatePreset)
    }

    func testStatePayloadRoundTrips() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        engine.start(now: start)
        engine.pause(now: start.addingTimeInterval(7))

        let decoded = TabataState.fromPayloadDictionary(engine.state.payloadDictionary())

        XCTAssertEqual(decoded, engine.state)
    }

    func testWatchCommandPayloadRoundTripsForFallbackDelivery() {
        let payload = WatchCommandPayload(command: .pause, soundsEnabled: nil)
        let decoded = WatchCommandPayload.fromPayloadDictionary(payload.payloadDictionary())

        XCTAssertEqual(decoded?.command, .pause)
        XCTAssertNil(decoded?.soundsEnabled)
    }

    func testInvalidPayloadsReturnNil() {
        XCTAssertNil(TabataState.fromPayloadDictionary(["phase": "bogus"]))
        XCTAssertNil(WatchCommandPayload.fromPayloadDictionary(["command": "bogus"]))
        XCTAssertNil(WatchCommandPayload.fromPayloadDictionary(["command": Date()]))
    }

    func testPresentationForIdleRunningPausedAndCompleteStates() {
        let start = Date(timeIntervalSince1970: 100)
        var engine = TabataEngine()

        let idle = TabataPresentation(state: engine.state)

        XCTAssertEqual(idle.title, "TABATA")
        XCTAssertEqual(idle.phoneRoundText, "8 rounds")
        XCTAssertEqual(idle.watchRoundText, "8 rounds")
        XCTAssertEqual(idle.primaryButtonTitle, "Start")
        XCTAssertEqual(idle.primaryAction, .toggleRunning)
        XCTAssertTrue(idle.isPrimaryButtonProminent)
        XCTAssertFalse(idle.showsReset)

        engine.start(now: start)
        let work = TabataPresentation(state: engine.state)

        XCTAssertEqual(work.title, "WORK")
        XCTAssertEqual(work.phoneRoundText, "Round 1 of 8")
        XCTAssertEqual(work.watchRoundText, "1 / 8")
        XCTAssertEqual(work.primaryButtonTitle, "Pause")
        XCTAssertFalse(work.isPrimaryButtonProminent)

        engine.pause(now: start.addingTimeInterval(5))
        let paused = TabataPresentation(state: engine.state)

        XCTAssertEqual(paused.title, "PAUSED")
        XCTAssertEqual(paused.primaryButtonTitle, "Resume")
        XCTAssertTrue(paused.isPrimaryButtonProminent)
        XCTAssertTrue(paused.showsReset)

        engine.resume(now: start.addingTimeInterval(10))
        let complete = TabataPresentation(state: engine.tick(now: start.addingTimeInterval(260)))

        XCTAssertEqual(complete.title, "DONE")
        XCTAssertEqual(complete.phoneRoundText, "Complete")
        XCTAssertEqual(complete.primaryButtonTitle, "Back Home")
        XCTAssertEqual(complete.primaryAction, .reset)
    }

    func testPresentationUsesSelectedConfigForIdleRounds() {
        let state = TabataState.idle(config: TabataConfig.preset(workSeconds: 45, restSeconds: 15, rounds: 6))
        let presentation = TabataPresentation(state: state)

        XCTAssertEqual(presentation.phoneRoundText, "6 rounds")
        XCTAssertEqual(presentation.watchRoundText, "6 rounds")
    }
}
