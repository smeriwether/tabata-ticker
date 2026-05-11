import AudioToolbox
import Combine
import SwiftUI
import UIKit

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published private(set) var state: TabataState

    private static let soundsEnabledKey = "soundsEnabled"

    private var engine: TabataEngine
    private let defaults: UserDefaults
    private let connectivity = PhoneConnectivity()
    private let cuePerformer = PhoneCuePerformer()
    private var lastCountdownCue: CountdownCue?
    private var didActivate = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var initialState = TabataState.idle()
        if defaults.object(forKey: Self.soundsEnabledKey) != nil {
            initialState.soundsEnabled = defaults.bool(forKey: Self.soundsEnabledKey)
        }

        state = initialState
        engine = TabataEngine(state: initialState)
    }

    var primaryButtonTitle: String {
        if state.phase == .complete {
            return "Back Home"
        }

        if state.phase == .idle {
            return "Start"
        }

        return state.isRunning ? "Pause" : "Resume"
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
        engine.toggleRunning(now: Date())
        state = engine.state
        updateIdleTimer()
        sendState()
    }

    func reset() {
        engine.reset()
        state = engine.state
        lastCountdownCue = nil
        updateIdleTimer()
        sendState()
    }

    func setSoundsEnabled(_ enabled: Bool) {
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
