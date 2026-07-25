import AVFoundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class WorkoutViewModel {
    private(set) var state: TabataState
    private(set) var now: Date
    private(set) var presetCatalog: TabataPresetCatalog

    private static let soundsEnabledKey = "soundsEnabled"
    private static let hapticsEnabledKey = "hapticsEnabled"
    private static let startCountdownEnabledKey = "startCountdownEnabled"

    @ObservationIgnored
    private var engine: TabataEngine
    private let defaults: UserDefaults
    private let presetStore: TabataPresetStore
    private let stateStore: TabataStateStore
    private let connectivity = PhoneConnectivity()
    private let cuePerformer = PhoneCuePerformer()
    private let liveActivityController = TabataLiveActivityController()
    @ObservationIgnored
    private var lastCountdownCue: CountdownCue?
    @ObservationIgnored
    private var didActivate = false
    @ObservationIgnored
    private var tickTask: Task<Void, Never>?

    private static var currentInstance: WorkoutViewModel?

    // Live Activity buttons run their intent in this process without the SwiftUI environment, so the
    // running view model is reachable here. It is created on demand, which covers a button press
    // that launches the app in the background: the workout it acts on is restored from disk.
    static func shared() -> WorkoutViewModel {
        if let currentInstance {
            return currentInstance
        }

        let workout = WorkoutViewModel()
        currentInstance = workout
        return workout
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let presetStore = TabataPresetStore(defaults: defaults)
        self.presetStore = presetStore
        let stateStore = TabataStateStore(defaults: defaults)
        self.stateStore = stateStore
        let presetCatalog = presetStore.loadCatalog()
        self.presetCatalog = presetCatalog

        var initialState = TabataState.idle(config: presetCatalog.selectedPreset.config)
        if defaults.object(forKey: Self.soundsEnabledKey) != nil {
            initialState.soundsEnabled = defaults.bool(forKey: Self.soundsEnabledKey)
        }
        if defaults.object(forKey: Self.hapticsEnabledKey) != nil {
            initialState.hapticsEnabled = defaults.bool(forKey: Self.hapticsEnabledKey)
        }
        if defaults.object(forKey: Self.startCountdownEnabledKey) != nil {
            initialState.startCountdownEnabled = defaults.bool(forKey: Self.startCountdownEnabledKey)
        }

        let now = Date()
        if var restored = stateStore.restore(now: now) {
            restored.soundsEnabled = initialState.soundsEnabled
            restored.hapticsEnabled = initialState.hapticsEnabled
            restored.startCountdownEnabled = initialState.startCountdownEnabled
            initialState = restored
        }

        state = initialState
        self.now = now
        engine = TabataEngine(state: initialState)
    }

    var presets: [TabataPreset] {
        presetCatalog.presets
    }

    var selectedPreset: TabataPreset {
        presetCatalog.selectedPreset
    }

    var canCreatePreset: Bool {
        presetCatalog.canCreatePreset
    }

    var canManageCustomPresets: Bool {
        !state.isRunning && !state.isWorkoutPhase
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
        publishState()
        syncRunningState()
    }

    func tick(now: Date = Date()) {
        let oldState = state
        self.now = now
        state = engine.tick(now: now)

        if state.soundsEnabled, TabataCuePolicy.needsTransitionCue(from: oldState, to: state) {
            cuePerformer.playTransition()
            lastCountdownCue = nil
        }

        if state.soundsEnabled, let cue = TabataCuePolicy.countdownCue(in: state, now: now), cue != lastCountdownCue {
            cuePerformer.playCountdown()
            lastCountdownCue = cue
        }

        syncRunningState()

        if oldState != state {
            publishState()
        }
    }

    func toggleRunning() {
        let now = Date()
        self.now = now
        engine.toggleRunning(now: now)
        state = engine.state
        syncRunningState()
        publishState()
    }

    func reset() {
        now = Date()
        let soundsEnabled = state.soundsEnabled
        let hapticsEnabled = state.hapticsEnabled
        let startCountdownEnabled = state.startCountdownEnabled
        var resetState = TabataState.idle(config: selectedPreset.config)
        resetState.soundsEnabled = soundsEnabled
        resetState.hapticsEnabled = hapticsEnabled
        resetState.startCountdownEnabled = startCountdownEnabled
        engine = TabataEngine(state: resetState)
        state = engine.state
        lastCountdownCue = nil
        syncRunningState()
        publishState()
    }

    func setSoundsEnabled(_ enabled: Bool) {
        now = Date()
        defaults.set(enabled, forKey: Self.soundsEnabledKey)
        engine.setSoundsEnabled(enabled)
        state = engine.state
        lastCountdownCue = nil
        publishState()
    }

    func selectPreset(_ preset: TabataPreset) {
        guard state.phase == .idle, presetCatalog.selectPreset(id: preset.id) else {
            return
        }

        presetStore.save(presetCatalog)
        resetToSelectedPreset()
    }

    @discardableResult
    func createPreset(config: TabataConfig) -> Bool {
        guard canManageCustomPresets, presetCatalog.addUserPreset(config: config) != nil else {
            return false
        }

        presetStore.save(presetCatalog)
        resetToSelectedPreset()
        return true
    }

    @discardableResult
    func updatePreset(id: String, config: TabataConfig) -> Bool {
        let wasSelected = presetCatalog.selectedID == id
        guard canManageCustomPresets, presetCatalog.updateUserPreset(id: id, config: config) else {
            return false
        }

        presetStore.save(presetCatalog)
        if wasSelected, state.phase == .idle || state.phase == .complete {
            resetToSelectedPreset()
        }
        return true
    }

    @discardableResult
    func deletePreset(id: String) -> Bool {
        let wasSelected = presetCatalog.selectedID == id
        guard canManageCustomPresets, presetCatalog.deleteUserPreset(id: id) else {
            return false
        }

        presetStore.save(presetCatalog)
        if wasSelected, state.phase == .idle || state.phase == .complete {
            resetToSelectedPreset()
        }
        return true
    }

    func setHapticsEnabled(_ enabled: Bool) {
        now = Date()
        defaults.set(enabled, forKey: Self.hapticsEnabledKey)
        engine.setHapticsEnabled(enabled)
        state = engine.state
        lastCountdownCue = nil
        publishState()
    }

    func setStartCountdownEnabled(_ enabled: Bool) {
        now = Date()
        defaults.set(enabled, forKey: Self.startCountdownEnabledKey)
        engine.setStartCountdownEnabled(enabled)
        state = engine.state
        lastCountdownCue = nil
        publishState()
    }

    private func handle(_ payload: WatchCommandPayload) {
        switch payload.command {
        case .start:
            start()
        case .pause:
            pause()
        case .resume:
            resume()
        case .reset:
            reset()
        case .setSoundsEnabled:
            setSoundsEnabled(payload.soundsEnabled ?? state.soundsEnabled)
        }
    }

    private func publishState() {
        connectivity.send(state)
        stateStore.save(state, at: now)
        liveActivityController.sync(state: state, now: now)
    }

    private func resetToSelectedPreset() {
        let soundsEnabled = state.soundsEnabled
        let hapticsEnabled = state.hapticsEnabled
        let startCountdownEnabled = state.startCountdownEnabled
        now = Date()

        var selectedState = TabataState.idle(config: selectedPreset.config)
        selectedState.soundsEnabled = soundsEnabled
        selectedState.hapticsEnabled = hapticsEnabled
        selectedState.startCountdownEnabled = startCountdownEnabled
        engine = TabataEngine(state: selectedState)
        state = selectedState
        lastCountdownCue = nil
        syncRunningState()
        publishState()
    }

    // The timer belongs to the view model rather than the view so a workout keeps running, cueing,
    // and updating its Live Activity while the app is in the background.
    private func syncRunningState() {
        if state.isRunning {
            startTicking()
        } else {
            stopTicking()
        }

        cuePerformer.setWorkoutAudioActive(state.isRunning)
        UIApplication.shared.isIdleTimerDisabled = state.isRunning
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
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    func start() {
        guard state.phase == .idle || state.phase == .complete else {
            return
        }

        now = Date()
        engine.start(now: now)
        state = engine.state
        lastCountdownCue = nil
        syncRunningState()
        publishState()
    }

    func pause() {
        guard state.isWorkoutPhase, state.isRunning else {
            return
        }

        now = Date()
        engine.pause(now: now)
        state = engine.state
        lastCountdownCue = nil
        syncRunningState()
        publishState()
    }

    func resume() {
        guard state.isWorkoutPhase, !state.isRunning else {
            return
        }

        now = Date()
        engine.resume(now: now)
        state = engine.state
        lastCountdownCue = nil
        syncRunningState()
        publishState()
    }
}

@MainActor
private final class PhoneCuePerformer {
    private static let duckReleaseDelay: TimeInterval = 1.5

    private let countdownPlayer: AVAudioPlayer?
    private let transitionPlayer: AVAudioPlayer?
    private let keepAlivePlayer: AVAudioPlayer?
    private var duckRelease: Task<Void, Never>?
    private var isWorkoutAudioActive = false
    private var didReportSessionFailure = false

    init() {
        // The category has to be in place before anything touches the audio hardware: the default
        // .soloAmbient category stops whatever the user is already listening to.
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: Self.categoryOptions(ducksOthers: false)
            )
        } catch {
            TabataDiagnostics.report("Configuring the audio session failed", error: error)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        countdownPlayer = Self.makePlayer(frequency: 880, duration: 0.08)
        transitionPlayer = Self.makePlayer(frequency: 1320, duration: 0.16)
        keepAlivePlayer = Self.makePlayer(frequency: 0, duration: 1, amplitude: 0)
        keepAlivePlayer?.numberOfLoops = -1

        if countdownPlayer == nil || transitionPlayer == nil || keepAlivePlayer == nil {
            TabataDiagnostics.report("Workout cue audio could not be prepared")
        }
    }

    // A running workout plays silence so iOS keeps the app alive with the screen off. This is called
    // on every tick as well as on state changes, so playback picks itself back up after an
    // interruption such as a phone call.
    func setWorkoutAudioActive(_ isActive: Bool) {
        isWorkoutAudioActive = isActive

        guard isActive else {
            releaseSessionIfIdle()
            return
        }

        guard let keepAlivePlayer, !keepAlivePlayer.isPlaying else {
            return
        }

        activateSession()
        keepAlivePlayer.play()
    }

    func playCountdown() {
        play(countdownPlayer)
    }

    func playTransition() {
        play(transitionPlayer)
    }

    private func play(_ player: AVAudioPlayer?) {
        guard let player else {
            return
        }

        duckRelease?.cancel()
        applyCategoryOptions(ducksOthers: true)
        activateSession()
        player.currentTime = 0
        player.play()
        scheduleDuckRelease(after: player.duration + Self.duckReleaseDelay)
    }

    // Other audio stays ducked for as long as the option is set, so it is dropped once the cues stop.
    // A cue landing inside the delay keeps the current duck instead of retriggering it.
    private func scheduleDuckRelease(after delay: TimeInterval) {
        duckRelease = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled, let self else {
                return
            }

            self.duckRelease = nil
            self.applyCategoryOptions(ducksOthers: false)
            self.releaseSessionIfIdle()
        }
    }

    // The session is held until the last cue has finished, so ending a workout never clips its final beep.
    private func releaseSessionIfIdle() {
        guard !isWorkoutAudioActive, duckRelease == nil else {
            return
        }

        keepAlivePlayer?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func applyCategoryOptions(ducksOthers: Bool) {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: Self.categoryOptions(ducksOthers: ducksOthers)
            )
        } catch {
            reportSessionFailureOnce("Adjusting the audio session failed", error: error)
        }
    }

    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            reportSessionFailureOnce("Activating the audio session failed", error: error)
        }
    }

    // Both callers run on every tick of a workout, so only the first failure of a launch is reported.
    private func reportSessionFailureOnce(_ context: String, error: any Error) {
        guard !didReportSessionFailure else {
            return
        }

        didReportSessionFailure = true
        TabataDiagnostics.report(context, error: error)
    }

    private static func categoryOptions(ducksOthers: Bool) -> AVAudioSession.CategoryOptions {
        ducksOthers ? [.mixWithOthers, .duckOthers] : [.mixWithOthers]
    }

    private static func makePlayer(frequency: Double, duration: Double, amplitude: Double = 0.25) -> AVAudioPlayer? {
        guard let data = toneData(frequency: frequency, duration: duration, amplitude: amplitude) else {
            return nil
        }

        return try? AVAudioPlayer(data: data)
    }

    private static func toneData(frequency: Double, duration: Double, amplitude: Double) -> Data? {
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
            let value = sin(2 * Double.pi * frequency * position) * Double(Int16.max) * amplitude * envelope
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
