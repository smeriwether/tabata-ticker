import AVFoundation
import Observation
import SwiftUI
import WatchKit

@MainActor
@Observable
final class WatchWorkoutViewModel {
    private(set) var state: TabataState
    private(set) var now: Date
    private(set) var catalog = TabataPresetCatalog()

    @ObservationIgnored
    private var engine: TabataEngine
    private let settingsStore: TabataSettingsStore
    private let connectivity = WatchConnectivity()
    private let cuePerformer = WatchCuePerformer()
    private let runtimeSessionController = WatchRuntimeSessionController()
    @ObservationIgnored
    private var lastCountdownCue: CountdownCue?
    @ObservationIgnored
    private var didActivate = false
    @ObservationIgnored
    private var tickTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        let settingsStore = TabataSettingsStore(defaults: defaults)
        self.settingsStore = settingsStore

        let initialState = TabataState.idle(settings: settingsStore.load())
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
        connectivity.onCatalog = { [weak self] catalog in
            self?.catalog = catalog
        }
        connectivity.activate()
    }

    var presets: [TabataPreset] {
        catalog.presets
    }

    var selectedPreset: TabataPreset {
        catalog.selectedPreset
    }

    var canSelectPreset: Bool {
        state.phase == .idle && catalog.presets.count > 1
    }

    // The phone owns the catalog, so the selection is echoed back with the new state; showing it
    // immediately keeps the watch from looking unresponsive while that round trip happens.
    func selectPreset(_ preset: TabataPreset) {
        guard state.phase == .idle, catalog.selectPreset(id: preset.id) else {
            return
        }

        connectivity.send(WatchCommandPayload(command: .selectPreset, soundsEnabled: nil, presetID: preset.id))
    }

    func tick(now: Date = Date()) {
        let oldState = state
        self.now = now
        state = engine.tick(now: now)

        if TabataCuePolicy.needsTransitionCue(from: oldState, to: state) {
            cuePerformer.playTransition(soundsEnabled: state.settings.soundsEnabled, hapticsEnabled: state.settings.hapticsEnabled)
            lastCountdownCue = nil
        }

        if let cue = TabataCuePolicy.countdownCue(in: state, now: now), cue != lastCountdownCue {
            cuePerformer.playCountdown(soundsEnabled: state.settings.soundsEnabled, hapticsEnabled: state.settings.hapticsEnabled)
            lastCountdownCue = cue
        }

        syncRunningState()
    }

    func toggleRunning() {
        let command = nextRunningCommand
        now = Date()
        engine.toggleRunning(now: now)
        state = engine.state
        lastCountdownCue = nil
        syncRunningState()
        connectivity.send(WatchCommandPayload(command: command, soundsEnabled: nil))
    }

    func reset() {
        now = Date()
        engine.reset()
        state = engine.state
        lastCountdownCue = nil
        syncRunningState()
        connectivity.send(WatchCommandPayload(command: .reset, soundsEnabled: nil))
    }

    func setSoundsEnabled(_ enabled: Bool) {
        now = Date()
        engine.updateSettings { $0.soundsEnabled = enabled }
        state = engine.state
        settingsStore.save(state.settings)
        lastCountdownCue = nil
        syncRunningState()
        connectivity.send(WatchCommandPayload(command: .setSoundsEnabled, soundsEnabled: enabled))
    }

    private func receive(_ newState: TabataState) {
        now = Date()
        settingsStore.save(newState.settings)
        state = newState
        engine = TabataEngine(state: newState)
        lastCountdownCue = nil
        syncRunningState()
    }

    private var nextRunningCommand: WatchCommand {
        if state.phase == .idle || state.phase == .complete {
            return .start
        }

        return state.isRunning ? .pause : .resume
    }

    private func syncRunningState() {
        if state.isRunning {
            startTicking()
        } else {
            stopTicking()
        }

        runtimeSessionController.setRunning(state.isRunning)
    }

    private func startTicking() {
        guard tickTask == nil else {
            return
        }

        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.state.isRunning else {
                    return
                }

                self.tick(now: Date())
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }
}

private final class WatchRuntimeSessionController: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?
    private var restartWorkItem: DispatchWorkItem?
    private var wantsSession = false

    func setRunning(_ isRunning: Bool) {
        wantsSession = isRunning

        if isRunning {
            start()
        } else {
            restartWorkItem?.cancel()
            restartWorkItem = nil
            stop()
        }
    }

    private func start() {
        guard session == nil else {
            return
        }

        restartWorkItem?.cancel()
        restartWorkItem = nil
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        self.session = session
        session.start()
    }

    private func stop() {
        session?.invalidate()
        session = nil
    }

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        guard session === extendedRuntimeSession else {
            return
        }

        session = nil
        if wantsSession {
            scheduleRestart()
        }
    }

    private func scheduleRestart() {
        restartWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.wantsSession, self.session == nil else {
                return
            }

            self.start()
        }
        restartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
}

private final class WatchCuePerformer {
    private let countdownPlayer: AVAudioPlayer?
    private let transitionPlayer: AVAudioPlayer?

    init() {
        // The category has to be in place before anything touches the audio hardware: the default
        // .soloAmbient category stops whatever the user is already listening to.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])

        countdownPlayer = Self.makePlayer(frequency: 880, duration: 0.08)
        transitionPlayer = Self.makePlayer(frequency: 1320, duration: 0.16)
    }

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
