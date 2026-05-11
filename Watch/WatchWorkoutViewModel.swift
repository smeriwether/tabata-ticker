import AVFoundation
import Combine
import SwiftUI
import WatchKit

@MainActor
final class WatchWorkoutViewModel: ObservableObject {
    @Published private(set) var state: TabataState

    private static let soundsEnabledKey = "soundsEnabled"

    private var engine: TabataEngine
    private let defaults: UserDefaults
    private let connectivity = WatchConnectivity()
    private let cuePerformer = WatchCuePerformer()
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
        connectivity.onState = { [weak self] state in
            self?.receive(state)
        }
        connectivity.activate()
    }

    func tick(now: Date = Date()) {
        let oldState = state
        state = engine.tick(now: now)

        if TabataCuePolicy.needsTransitionCue(from: oldState, to: state) {
            cuePerformer.playTransition()
            lastCountdownCue = nil
        }

        if let cue = TabataCuePolicy.countdownCue(in: state, now: now), cue != lastCountdownCue {
            cuePerformer.playCountdown()
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
        defaults.set(enabled, forKey: Self.soundsEnabledKey)
        state.soundsEnabled = enabled
        engine = TabataEngine(state: state)
        lastCountdownCue = nil
        connectivity.send(WatchCommandPayload(command: .setSoundsEnabled, soundsEnabled: enabled))
    }

    private func receive(_ newState: TabataState) {
        defaults.set(newState.soundsEnabled, forKey: Self.soundsEnabledKey)
        state = newState
        engine = TabataEngine(state: newState)
        lastCountdownCue = nil
    }
}

private final class WatchCuePerformer {
    private var player: AVAudioPlayer?

    func playCountdown() {
        playTone(frequency: 880, duration: 0.08)
        WKInterfaceDevice.current().play(.click)
    }

    func playTransition() {
        playTone(frequency: 1320, duration: 0.16)
        WKInterfaceDevice.current().play(.notification)
    }

    private func playTone(frequency: Double, duration: Double) {
        guard let data = toneData(frequency: frequency, duration: duration) else {
            return
        }

        player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
        player?.play()
    }

    private func toneData(frequency: Double, duration: Double) -> Data? {
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

    private func append(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
    }

    private func append<T>(_ value: T, to data: inout Data) {
        var value = value
        withUnsafeBytes(of: &value) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}
