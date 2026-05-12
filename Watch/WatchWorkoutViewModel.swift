import AVFoundation
import Observation
import SwiftUI
import WatchKit

@MainActor
@Observable
final class WatchWorkoutViewModel {
    private(set) var state: TabataState
    private(set) var now: Date

    private static let soundsEnabledKey = "soundsEnabled"
    private static let hapticsEnabledKey = "hapticsEnabled"

    @ObservationIgnored
    private var engine: TabataEngine
    private let defaults: UserDefaults
    private let connectivity = WatchConnectivity()
    private let cuePerformer = WatchCuePerformer()
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
        connectivity.onState = { [weak self] state in
            self?.receive(state)
        }
        connectivity.activate()
    }

    func tick(now: Date = Date()) {
        let oldState = state
        self.now = now
        state = engine.tick(now: now)

        if TabataCuePolicy.needsTransitionCue(from: oldState, to: state) {
            cuePerformer.playTransition(soundsEnabled: state.soundsEnabled, hapticsEnabled: state.hapticsEnabled)
            lastCountdownCue = nil
        }

        if let cue = TabataCuePolicy.countdownCue(in: state, now: now), cue != lastCountdownCue {
            cuePerformer.playCountdown(soundsEnabled: state.soundsEnabled, hapticsEnabled: state.hapticsEnabled)
            lastCountdownCue = cue
        }
    }

    func toggleRunning() {
        connectivity.send(WatchCommandPayload(command: .toggleRunning, soundsEnabled: nil))
    }

    func reset() {
        connectivity.send(WatchCommandPayload(command: .reset, soundsEnabled: nil))
    }

    func setSoundsEnabled(_ enabled: Bool) {
        now = Date()
        defaults.set(enabled, forKey: Self.soundsEnabledKey)
        state.soundsEnabled = enabled
        engine = TabataEngine(state: state)
        lastCountdownCue = nil
        connectivity.send(WatchCommandPayload(command: .setSoundsEnabled, soundsEnabled: enabled))
    }

    private func receive(_ newState: TabataState) {
        now = Date()
        defaults.set(newState.soundsEnabled, forKey: Self.soundsEnabledKey)
        defaults.set(newState.hapticsEnabled, forKey: Self.hapticsEnabledKey)
        state = newState
        engine = TabataEngine(state: newState)
        lastCountdownCue = nil
    }
}

private final class WatchCuePerformer {
    private let countdownPlayer = WatchCuePerformer.makePlayer(frequency: 880, duration: 0.08)
    private let transitionPlayer = WatchCuePerformer.makePlayer(frequency: 1320, duration: 0.16)

    func playCountdown(soundsEnabled: Bool, hapticsEnabled: Bool) {
        if soundsEnabled {
            play(countdownPlayer)
        }
        if hapticsEnabled {
            WKInterfaceDevice.current().play(.click)
        }
    }

    func playTransition(soundsEnabled: Bool, hapticsEnabled: Bool) {
        if soundsEnabled {
            play(transitionPlayer)
        }
        if hapticsEnabled {
            WKInterfaceDevice.current().play(.notification)
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

    private func play(_ player: AVAudioPlayer?) {
        player?.currentTime = 0
        player?.play()
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
