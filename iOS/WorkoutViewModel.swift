import AudioToolbox
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class WorkoutViewModel {
    private(set) var state: TabataState
    private(set) var now: Date

    private static let soundsEnabledKey = "soundsEnabled"

    @ObservationIgnored
    private var engine: TabataEngine
    private let defaults: UserDefaults
    private let connectivity = PhoneConnectivity()
    private let cuePerformer = PhoneCuePerformer()
    @ObservationIgnored
    private var lastCountdownCue: CountdownCue?
    @ObservationIgnored
    private var didActivate = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var initialState = TabataState.idle()
        if defaults.object(forKey: Self.soundsEnabledKey) != nil {
            initialState.soundsEnabled = defaults.bool(forKey: Self.soundsEnabledKey)
        }

        state = initialState
        now = Date()
        engine = TabataEngine(state: initialState)
    }

    func activate() {
        guard !didActivate else {
            return
        }

        didActivate = true
        connectivity.onCommand = { [weak self] command in
            self?.handle(command)
        }
        connectivity.activate()
        sendState()
    }

    func tick(now: Date = Date()) {
        let oldState = state
        self.now = now
        state = engine.tick(now: now)
        updateIdleTimer()

        if TabataCuePolicy.needsTransitionCue(from: oldState, to: state) {
            cuePerformer.playTransition()
            lastCountdownCue = nil
        }

        if let cue = TabataCuePolicy.countdownCue(in: state, now: now), cue != lastCountdownCue {
            cuePerformer.playCountdown()
            lastCountdownCue = cue
        }

        if oldState != state {
            sendState()
        }
    }

    func toggleRunning() {
        let now = Date()
        self.now = now
        engine.toggleRunning(now: now)
        state = engine.state
        updateIdleTimer()
        sendState()
    }

    func reset() {
        now = Date()
        engine.reset()
        state = engine.state
        lastCountdownCue = nil
        updateIdleTimer()
        sendState()
    }

    func setSoundsEnabled(_ enabled: Bool) {
        now = Date()
        defaults.set(enabled, forKey: Self.soundsEnabledKey)
        engine.setSoundsEnabled(enabled)
        state = engine.state
        lastCountdownCue = nil
        sendState()
    }

    private func handle(_ payload: WatchCommandPayload) {
        switch payload.command {
        case .toggleRunning:
            toggleRunning()
        case .reset:
            reset()
        case .setSoundsEnabled:
            setSoundsEnabled(payload.soundsEnabled ?? state.soundsEnabled)
        }
    }

    private func sendState() {
        connectivity.send(state)
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = state.isRunning
    }
}

private struct PhoneCuePerformer {
    func playCountdown() {
        AudioServicesPlaySystemSound(1104)
    }

    func playTransition() {
        AudioServicesPlaySystemSound(1005)
    }
}
