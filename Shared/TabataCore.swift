import Foundation

enum TabataPhase: String, Codable, Equatable, Sendable {
    case idle
    case countdown
    case work
    case rest
    case complete
}

struct TabataConfig: Codable, Equatable, Sendable {
    var rounds: Int
    var workDuration: TimeInterval
    var restDuration: TimeInterval

    static let classic = TabataConfig(rounds: 8, workDuration: 20, restDuration: 10)

    static func preset(workSeconds: Int, restSeconds: Int, rounds: Int) -> TabataConfig {
        TabataConfig(
            rounds: rounds,
            workDuration: TimeInterval(workSeconds),
            restDuration: TimeInterval(restSeconds)
        )
    }

    var workSeconds: Int {
        Int(workDuration.rounded())
    }

    var restSeconds: Int {
        Int(restDuration.rounded())
    }

    var presetName: String {
        "\(workSeconds)/\(restSeconds)/\(rounds)"
    }
}

struct TabataPreset: Codable, Equatable, Identifiable, Sendable {
    static let defaultID = "classic"
    static let classic = TabataPreset(id: defaultID, config: .classic, isDefault: true)

    var id: String
    var config: TabataConfig
    var isDefault: Bool

    var name: String {
        config.presetName
    }
}

struct TabataPresetCatalog: Equatable, Sendable {
    static let maxPresetCount = 4

    private(set) var presets: [TabataPreset]
    private(set) var selectedID: String

    init(customPresets: [TabataPreset] = [], selectedID: String? = nil) {
        let userPresets = Self.cleanUserPresets(customPresets)
        presets = [TabataPreset.classic] + userPresets

        if let selectedID, presets.contains(where: { $0.id == selectedID }) {
            self.selectedID = selectedID
        } else {
            self.selectedID = TabataPreset.defaultID
        }
    }

    var selectedPreset: TabataPreset {
        presets.first { $0.id == selectedID } ?? .classic
    }

    var userPresets: [TabataPreset] {
        presets.filter { !$0.isDefault }
    }

    var canCreatePreset: Bool {
        presets.count < Self.maxPresetCount
    }

    @discardableResult
    mutating func selectPreset(id: String) -> Bool {
        guard presets.contains(where: { $0.id == id }) else {
            return false
        }

        selectedID = id
        return true
    }

    mutating func addUserPreset(config: TabataConfig, id: String = UUID().uuidString) -> TabataPreset? {
        guard canCreatePreset else {
            return nil
        }

        let preset = TabataPreset(id: id, config: config, isDefault: false)
        presets.append(preset)
        selectedID = preset.id
        return preset
    }

    @discardableResult
    mutating func updateUserPreset(id: String, config: TabataConfig) -> Bool {
        guard let index = presets.firstIndex(where: { $0.id == id && !$0.isDefault }) else {
            return false
        }

        presets[index].config = config
        return true
    }

    @discardableResult
    mutating func deleteUserPreset(id: String) -> Bool {
        guard let index = presets.firstIndex(where: { $0.id == id && !$0.isDefault }) else {
            return false
        }

        presets.remove(at: index)
        if selectedID == id {
            selectedID = TabataPreset.defaultID
        }
        return true
    }

    private static func cleanUserPresets(_ presets: [TabataPreset]) -> [TabataPreset] {
        var cleaned: [TabataPreset] = []

        for preset in presets where !preset.isDefault && preset.id != TabataPreset.defaultID {
            guard cleaned.count < maxPresetCount - 1 else {
                continue
            }

            cleaned.append(TabataPreset(id: preset.id, config: preset.config, isDefault: false))
        }

        return cleaned
    }
}

// Shared code is built for the watch and for tests as well as the iPhone app, so it reports failures
// through this seam instead of depending on a crash reporter directly. The iPhone app points it at
// Sentry during launch, before anything else can report, which is why the unchecked access is safe.
enum TabataDiagnostics {
    nonisolated(unsafe) private static var reporter: (@Sendable (String, (any Error)?) -> Void)?

    static func setReporter(_ reporter: @escaping @Sendable (String, (any Error)?) -> Void) {
        Self.reporter = reporter
    }

    static func report(_ context: String, error: (any Error)? = nil) {
        reporter?(context, error)
    }
}

struct TabataPresetStore {
    private static let customPresetsKey = "tabataPreset.customPresets"
    private static let selectedPresetIDKey = "tabataPreset.selectedPresetID"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadCatalog() -> TabataPresetCatalog {
        TabataPresetCatalog(
            customPresets: loadUserPresets(),
            selectedID: defaults.string(forKey: Self.selectedPresetIDKey)
        )
    }

    func save(_ catalog: TabataPresetCatalog) {
        do {
            defaults.set(try JSONEncoder().encode(catalog.userPresets), forKey: Self.customPresetsKey)
        } catch {
            TabataDiagnostics.report("Saving custom presets failed", error: error)
        }

        defaults.set(catalog.selectedID, forKey: Self.selectedPresetIDKey)
    }

    private func loadUserPresets() -> [TabataPreset] {
        guard let data = defaults.data(forKey: Self.customPresetsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([TabataPreset].self, from: data)
        } catch {
            TabataDiagnostics.report("Stored custom presets could not be read", error: error)
            return []
        }
    }
}

struct TabataStateStore {
    static let maxRestoreAge: TimeInterval = 6 * 60 * 60

    private static let stateKey = "tabataState.active"
    private static let savedAtKey = "tabataState.activeSavedAt"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ state: TabataState, at date: Date) {
        guard Self.isUnfinished(state) else {
            clear()
            return
        }

        do {
            defaults.set(try JSONEncoder().encode(state), forKey: Self.stateKey)
            defaults.set(date.timeIntervalSince1970, forKey: Self.savedAtKey)
        } catch {
            TabataDiagnostics.report("Saving the active workout failed", error: error)
        }
    }

    func clear() {
        defaults.removeObject(forKey: Self.stateKey)
        defaults.removeObject(forKey: Self.savedAtKey)
    }

    func restore(now: Date) -> TabataState? {
        guard let data = defaults.data(forKey: Self.stateKey) else {
            return nil
        }

        do {
            let state = try JSONDecoder().decode(TabataState.self, from: data)
            return Self.restorable(state, savedAt: Date(timeIntervalSince1970: defaults.double(forKey: Self.savedAtKey)), now: now)
        } catch {
            TabataDiagnostics.report("Stored workout could not be read", error: error)
            clear()
            return nil
        }
    }

    // A workout only comes back if it was interrupted recently and is still under way, so reopening
    // the app hours later starts fresh instead of resuming something the user has long since left.
    static func restorable(_ state: TabataState, savedAt: Date, now: Date) -> TabataState? {
        guard isUnfinished(state) else {
            return nil
        }

        let age = now.timeIntervalSince(savedAt)
        guard age >= 0, age < maxRestoreAge else {
            return nil
        }

        var engine = TabataEngine(state: state)
        let advanced = engine.tick(now: now)
        return isUnfinished(advanced) ? advanced : nil
    }

    private static func isUnfinished(_ state: TabataState) -> Bool {
        state.phase == .countdown || state.isWorkoutPhase
    }
}

struct TabataState: Codable, Equatable, Sendable {
    static let startCountdownDuration: TimeInterval = 5

    var config: TabataConfig
    var phase: TabataPhase
    var round: Int
    var phaseStartedAt: Date?
    var phaseDuration: TimeInterval
    var isRunning: Bool
    var pausedRemaining: TimeInterval?
    var soundsEnabled: Bool
    var hapticsEnabled: Bool
    var startCountdownEnabled: Bool

    static func idle(config: TabataConfig = .classic) -> TabataState {
        TabataState(
            config: config,
            phase: .idle,
            round: 0,
            phaseStartedAt: nil,
            phaseDuration: config.workDuration,
            isRunning: false,
            pausedRemaining: config.workDuration,
            soundsEnabled: true,
            hapticsEnabled: true,
            startCountdownEnabled: true
        )
    }

    var isWorkoutPhase: Bool {
        phase == .work || phase == .rest
    }

    func remaining(at now: Date) -> TimeInterval {
        if !isRunning {
            return max(0, pausedRemaining ?? phaseDuration)
        }

        guard let phaseStartedAt else {
            return max(0, phaseDuration)
        }

        return max(0, phaseDuration - now.timeIntervalSince(phaseStartedAt))
    }

}

extension TabataState {
    private enum CodingKeys: String, CodingKey {
        case config
        case phase
        case round
        case phaseStartedAt
        case phaseDuration
        case isRunning
        case pausedRemaining
        case soundsEnabled
        case hapticsEnabled
        case startCountdownEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        config = try container.decode(TabataConfig.self, forKey: .config)
        phase = try container.decode(TabataPhase.self, forKey: .phase)
        round = try container.decode(Int.self, forKey: .round)
        phaseStartedAt = try container.decodeIfPresent(Date.self, forKey: .phaseStartedAt)
        phaseDuration = try container.decode(TimeInterval.self, forKey: .phaseDuration)
        isRunning = try container.decode(Bool.self, forKey: .isRunning)
        pausedRemaining = try container.decodeIfPresent(TimeInterval.self, forKey: .pausedRemaining)
        soundsEnabled = try container.decode(Bool.self, forKey: .soundsEnabled)
        hapticsEnabled = try container.decode(Bool.self, forKey: .hapticsEnabled)
        startCountdownEnabled = try container.decodeIfPresent(Bool.self, forKey: .startCountdownEnabled) ?? true
    }
}

struct TabataColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
}

struct TabataGradient: Equatable, Sendable {
    var start: TabataColor
    var end: TabataColor
}

enum TabataPrimaryAction: Equatable, Sendable {
    case toggleRunning
    case reset
}

struct TabataPresentation: Equatable, Sendable {
    var title: String
    var phoneRoundText: String
    var watchRoundText: String
    var background: TabataGradient
    var primaryButtonTitle: String
    var primaryAction: TabataPrimaryAction
    var isPrimaryButtonProminent: Bool
    var showsReset: Bool

    init(state: TabataState) {
        let isPaused = state.isWorkoutPhase && !state.isRunning

        showsReset = isPaused
        isPrimaryButtonProminent = state.phase == .idle || state.phase == .complete || isPaused

        if state.phase == .complete {
            primaryButtonTitle = "Back Home"
            primaryAction = .reset
        } else if state.phase == .countdown {
            primaryButtonTitle = "Cancel"
            primaryAction = .reset
        } else if state.phase == .idle {
            primaryButtonTitle = "Start"
            primaryAction = .toggleRunning
        } else {
            primaryButtonTitle = state.isRunning ? "Pause" : "Resume"
            primaryAction = .toggleRunning
        }

        switch state.phase {
        case .idle:
            phoneRoundText = "\(state.config.rounds) rounds"
            watchRoundText = "\(state.config.rounds) rounds"
        case .countdown:
            phoneRoundText = "Get ready"
            watchRoundText = "Get ready"
        case .complete:
            phoneRoundText = "Complete"
            watchRoundText = "Complete"
        case .work, .rest:
            phoneRoundText = "Round \(state.round) of \(state.config.rounds)"
            watchRoundText = "\(state.round) / \(state.config.rounds)"
        }

        if isPaused {
            title = "PAUSED"
            background = .paused
        } else {
            switch state.phase {
            case .idle:
                title = "TABATA"
                background = .idle
            case .countdown:
                title = "READY"
                background = .countdown
            case .work:
                title = "WORK"
                background = .work
            case .rest:
                title = "REST"
                background = .rest
            case .complete:
                title = "DONE"
                background = .complete
            }
        }
    }
}

private extension TabataGradient {
    static let idle = TabataGradient(
        start: TabataColor(red: 0.03, green: 0.52, blue: 0.50),
        end: TabataColor(red: 0.18, green: 0.24, blue: 0.72)
    )
    static let work = TabataGradient(
        start: TabataColor(red: 0.92, green: 0.48, blue: 0.12),
        end: TabataColor(red: 0.70, green: 0.30, blue: 0.06)
    )
    static let countdown = TabataGradient(
        start: TabataColor(red: 0.12, green: 0.60, blue: 0.70),
        end: TabataColor(red: 0.22, green: 0.26, blue: 0.76)
    )
    static let rest = TabataGradient(
        start: TabataColor(red: 0.00, green: 0.48, blue: 0.95),
        end: TabataColor(red: 0.04, green: 0.24, blue: 0.78)
    )
    static let complete = TabataGradient(
        start: TabataColor(red: 0.08, green: 0.64, blue: 0.40),
        end: TabataColor(red: 0.04, green: 0.38, blue: 0.29)
    )
    static let paused = TabataGradient(
        start: TabataColor(red: 0.24, green: 0.24, blue: 0.27),
        end: TabataColor(red: 0.10, green: 0.11, blue: 0.13)
    )
}

struct TabataEngine {
    private(set) var state: TabataState

    init(state: TabataState = .idle()) {
        self.state = state
    }

    mutating func start(now: Date) {
        guard state.phase == .idle || state.phase == .complete else {
            resume(now: now)
            return
        }

        if state.startCountdownEnabled {
            startCountdown(now: now)
            return
        }

        startWork(now: now)
    }

    private mutating func startCountdown(now: Date) {
        let soundsEnabled = state.soundsEnabled
        let hapticsEnabled = state.hapticsEnabled
        let startCountdownEnabled = state.startCountdownEnabled
        state = TabataState(
            config: state.config,
            phase: .countdown,
            round: 0,
            phaseStartedAt: now,
            phaseDuration: TabataState.startCountdownDuration,
            isRunning: true,
            pausedRemaining: nil,
            soundsEnabled: soundsEnabled,
            hapticsEnabled: hapticsEnabled,
            startCountdownEnabled: startCountdownEnabled
        )
    }

    private mutating func startWork(now: Date) {
        let soundsEnabled = state.soundsEnabled
        let hapticsEnabled = state.hapticsEnabled
        let startCountdownEnabled = state.startCountdownEnabled
        state = TabataState(
            config: state.config,
            phase: .work,
            round: 1,
            phaseStartedAt: now,
            phaseDuration: state.config.workDuration,
            isRunning: true,
            pausedRemaining: nil,
            soundsEnabled: soundsEnabled,
            hapticsEnabled: hapticsEnabled,
            startCountdownEnabled: startCountdownEnabled
        )
    }

    mutating func pause(now: Date) {
        guard state.isWorkoutPhase, state.isRunning else {
            return
        }

        state.pausedRemaining = state.remaining(at: now)
        state.isRunning = false
    }

    mutating func resume(now: Date) {
        guard state.isWorkoutPhase, !state.isRunning else {
            return
        }

        let remaining = state.remaining(at: now)
        state.phaseStartedAt = now.addingTimeInterval(-(state.phaseDuration - remaining))
        state.pausedRemaining = nil
        state.isRunning = true
    }

    mutating func toggleRunning(now: Date) {
        if state.phase == .idle || state.phase == .complete {
            start(now: now)
        } else if state.isRunning {
            pause(now: now)
        } else {
            resume(now: now)
        }
    }

    mutating func reset() {
        let soundsEnabled = state.soundsEnabled
        let hapticsEnabled = state.hapticsEnabled
        let startCountdownEnabled = state.startCountdownEnabled
        state = .idle(config: state.config)
        state.soundsEnabled = soundsEnabled
        state.hapticsEnabled = hapticsEnabled
        state.startCountdownEnabled = startCountdownEnabled
    }

    mutating func setSoundsEnabled(_ enabled: Bool) {
        state.soundsEnabled = enabled
    }

    mutating func setHapticsEnabled(_ enabled: Bool) {
        state.hapticsEnabled = enabled
    }

    mutating func setStartCountdownEnabled(_ enabled: Bool) {
        state.startCountdownEnabled = enabled
    }

    mutating func tick(now: Date) -> TabataState {
        advance(now: now)
        return state
    }

    private mutating func advance(now: Date) {
        guard state.isRunning, state.phase == .countdown || state.isWorkoutPhase else {
            return
        }

        while state.isRunning, state.phase == .countdown || state.isWorkoutPhase {
            guard let startedAt = state.phaseStartedAt else {
                return
            }

            let elapsed = now.timeIntervalSince(startedAt)
            guard elapsed >= state.phaseDuration else {
                return
            }

            let nextStartedAt = startedAt.addingTimeInterval(state.phaseDuration)

            switch state.phase {
            case .countdown:
                state.phase = .work
                state.round = 1
                state.phaseStartedAt = nextStartedAt
                state.phaseDuration = state.config.workDuration
            case .work where state.round < state.config.rounds:
                state.phase = .rest
                state.phaseStartedAt = nextStartedAt
                state.phaseDuration = state.config.restDuration
            case .work:
                state.phase = .complete
                state.phaseStartedAt = nil
                state.phaseDuration = 0
                state.isRunning = false
                state.pausedRemaining = 0
            case .rest where state.round < state.config.rounds:
                state.round += 1
                state.phase = .work
                state.phaseStartedAt = nextStartedAt
                state.phaseDuration = state.config.workDuration
            case .rest:
                state.phase = .complete
                state.phaseStartedAt = nil
                state.phaseDuration = 0
                state.isRunning = false
                state.pausedRemaining = 0
            case .idle, .complete:
                return
            }
        }
    }
}

struct CountdownCue: Hashable, Sendable {
    var phase: TabataPhase
    var round: Int
    var second: Int
}

enum TabataCuePolicy {
    static func countdownCue(in state: TabataState, now: Date) -> CountdownCue? {
        guard (state.soundsEnabled || state.hapticsEnabled), state.isRunning, state.phase == .countdown || state.isWorkoutPhase else {
            return nil
        }

        let second = Int(ceil(state.remaining(at: now)))
        let threshold: Int
        switch state.phase {
        case .countdown, .work:
            threshold = 5
        case .rest:
            threshold = 3
        case .idle, .complete:
            return nil
        }

        guard (1...threshold).contains(second) else {
            return nil
        }

        return CountdownCue(phase: state.phase, round: state.round, second: second)
    }

    static func needsTransitionCue(from oldState: TabataState, to newState: TabataState) -> Bool {
        guard newState.soundsEnabled || newState.hapticsEnabled else {
            return false
        }

        if oldState.phase == .idle, newState.phase == .work {
            return false
        }

        return oldState.phase != newState.phase || oldState.round != newState.round
    }
}

enum WatchCommand: String, Codable, Sendable {
    case start
    case pause
    case resume
    case reset
    case setSoundsEnabled
    case selectPreset
}

struct WatchCommandPayload: Codable, Sendable {
    var command: WatchCommand
    var soundsEnabled: Bool?
    var presetID: String?

    init(command: WatchCommand, soundsEnabled: Bool? = nil, presetID: String? = nil) {
        self.command = command
        self.soundsEnabled = soundsEnabled
        self.presetID = presetID
    }
}

extension TabataState {
    private enum SyncKey {
        static let presets = "syncPresets"
        static let selectedPresetID = "syncSelectedPresetID"
    }

    func payloadDictionary() -> [String: Any] {
        CodablePayload.dictionary(from: self)
    }

    // The catalog rides in the same dictionary as the state rather than replacing it, so a watch
    // build that only knows about the state keys keeps mirroring a newer phone.
    func payloadDictionary(catalog: TabataPresetCatalog) -> [String: Any] {
        var dictionary = payloadDictionary()
        dictionary[SyncKey.presets] = CodablePayload.array(from: catalog.presets)
        dictionary[SyncKey.selectedPresetID] = catalog.selectedID
        return dictionary
    }

    static func fromPayloadDictionary(_ dictionary: [String: Any]) -> TabataState? {
        CodablePayload.value(TabataState.self, from: dictionary)
    }

    static func catalogFromPayloadDictionary(_ dictionary: [String: Any]) -> TabataPresetCatalog? {
        guard
            let rawPresets = dictionary[SyncKey.presets] as? [Any],
            let selectedID = dictionary[SyncKey.selectedPresetID] as? String
        else {
            return nil
        }

        let presets = CodablePayload.values(TabataPreset.self, from: rawPresets)
        guard !presets.isEmpty else {
            return nil
        }

        return TabataPresetCatalog(customPresets: presets.filter { !$0.isDefault }, selectedID: selectedID)
    }
}

extension WatchCommandPayload {
    func payloadDictionary() -> [String: Any] {
        CodablePayload.dictionary(from: self)
    }

    static func fromPayloadDictionary(_ dictionary: [String: Any]) -> WatchCommandPayload? {
        CodablePayload.value(WatchCommandPayload.self, from: dictionary)
    }
}

private enum CodablePayload {
    static func dictionary<T: Encodable>(from value: T) -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        guard
            let data = try? encoder.encode(value),
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return [:]
        }

        return dictionary
    }

    static func array<T: Encodable>(from values: [T]) -> [[String: Any]] {
        values.map { dictionary(from: $0) }.filter { !$0.isEmpty }
    }

    static func values<T: Decodable>(_ type: T.Type, from array: [Any]) -> [T] {
        array.compactMap { element in
            guard let dictionary = element as? [String: Any] else {
                return nil
            }

            return value(type, from: dictionary)
        }
    }

    static func value<T: Decodable>(_ type: T.Type, from dictionary: [String: Any]) -> T? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        guard
            JSONSerialization.isValidJSONObject(dictionary),
            let data = try? JSONSerialization.data(withJSONObject: dictionary),
            let value = try? decoder.decode(type, from: data)
        else {
            return nil
        }

        return value
    }
}
