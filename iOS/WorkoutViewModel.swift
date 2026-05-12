import AVFoundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class WorkoutViewModel {
    private(set) var state: TabataState
    private(set) var now: Date

    private static let soundsEnabledKey = "soundsEnabled"
    private static let hapticsEnabledKey = "hapticsEnabled"

    @ObservationIgnored
    private var engine: TabataEngine
    private let defaults: UserDefaults
    private let connectivity = PhoneConnectivity()
    private let cuePerformer = PhoneCuePerformer()
    private let liveActivityController = TabataLiveActivityController()
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
        if defaults.object(forKey: Self.hapticsEnabledKey) != nil {
            initialState.hapticsEnabled = defaults.bool(forKey: Self.hapticsEnabledKey)
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
        syncLiveActivity()
    }

    func tick(now: Date = Date()) {
        let oldState = state
        self.now = now
        state = engine.tick(now: now)
        updateIdleTimer()

        if state.soundsEnabled, TabataCuePolicy.needsTransitionCue(from: oldState, to: state) {
            cuePerformer.playTransition()
            lastCountdownCue = nil
        }

        if state.soundsEnabled, let cue = TabataCuePolicy.countdownCue(in: state, now: now), cue != lastCountdownCue {
            cuePerformer.playCountdown()
            lastCountdownCue = cue
        }

        if oldState != state {
            sendState()
            syncLiveActivity()
        }
    }

    func toggleRunning() {
        let now = Date()
        self.now = now
        engine.toggleRunning(now: now)
        state = engine.state
        updateIdleTimer()
        sendState()
        syncLiveActivity()
    }

    func reset() {
        now = Date()
        engine.reset()
        state = engine.state
        lastCountdownCue = nil
        updateIdleTimer()
        sendState()
        syncLiveActivity()
    }

    func setSoundsEnabled(_ enabled: Bool) {
        now = Date()
        defaults.set(enabled, forKey: Self.soundsEnabledKey)
        engine.setSoundsEnabled(enabled)
        state = engine.state
        lastCountdownCue = nil
        sendState()
    }

    func setHapticsEnabled(_ enabled: Bool) {
        now = Date()
        defaults.set(enabled, forKey: Self.hapticsEnabledKey)
        engine.setHapticsEnabled(enabled)
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

    private func syncLiveActivity() {
        liveActivityController.sync(state: state, now: now)
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = state.isRunning
    }
}

private final class PhoneCuePerformer {
    private let countdownPlayer = PhoneCuePerformer.makePlayer(frequency: 880, duration: 0.08)
    private let transitionPlayer = PhoneCuePerformer.makePlayer(frequency: 1320, duration: 0.16)
    private var didConfigureSession = false

    func playCountdown() {
        play(countdownPlayer)
    }

    func playTransition() {
        play(transitionPlayer)
    }

    private func play(_ player: AVAudioPlayer?) {
        configureSession()
        player?.currentTime = 0
        player?.play()
    }

    private func configureSession() {
        guard !didConfigureSession else {
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            didConfigureSession = true
        } catch {
            return
        }
    }

    private static func makePlayer(frequency: Double, duration: Double) -> AVAudioPlayer? {
        guard let data = toneData(frequency: frequency, duration: duration) else {
            return nil
        }

        let player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
        return player
    }

    private static func toneData(frequency: Double, duration: Double) -> Data? {
        let sampleRate = 22_050
        let sampleCount = Int(duration * Double(sampleRate))
        let byteCount = sampleCount * MemoryLayout<Int16>.size
        var data = Data()

        append("RIFF", to: &data)
        append(UInt32(36 + byteCount).littleEndian, to: &data)
        append("WAVE", to: &data)
        append("fmt ", to: &data)
        append(UInt32(16).littleEndian, to: &data)
        append(UInt16(1).littleEndian, to: &data)
        append(UInt16(1).littleEndian, to: &data)
        append(UInt32(sampleRate).littleEndian, to: &data)
        append(UInt32(sampleRate * MemoryLayout<Int16>.size).littleEndian, to: &data)
        append(UInt16(MemoryLayout<Int16>.size).littleEndian, to: &data)
        append(UInt16(16).littleEndian, to: &data)
        append("data", to: &data)
        append(UInt32(byteCount).littleEndian, to: &data)

        for sampleIndex in 0..<sampleCount {
            let position = Double(sampleIndex) / Double(sampleRate)
            let envelope = min(1, Double(sampleCount - sampleIndex) / Double(sampleCount) * 4)
            let value = sin(2 * Double.pi * frequency * position) * Double(Int16.max) * 0.25 * envelope
            append(Int16(value).littleEndian, to: &data)
        }

        return data
    }

    private static func append(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
    }

    private static func append<T>(_ value: T, to data: inout Data) {
        var value = value
        withUnsafeBytes(of: &value) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}
