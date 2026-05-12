import Foundation

enum TabataPhase: String, Codable, Equatable, Sendable {
    case idle
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
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(catalog.userPresets) {
            defaults.set(data, forKey: Self.customPresetsKey)
        }
        defaults.set(catalog.selectedID, forKey: Self.selectedPresetIDKey)
    }

    private func loadUserPresets() -> [TabataPreset] {
        guard let data = defaults.data(forKey: Self.customPresetsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([TabataPreset].self, from: data)) ?? []
    }
}

struct TabataState: Codable, Equatable, Sendable {
    var config: TabataConfig
    var phase: TabataPhase
    var round: Int
    var phaseStartedAt: Date?
    var phaseDuration: TimeInterval
    var isRunning: Bool
    var pausedRemaining: TimeInterval?
    var soundsEnabled: Bool
    var hapticsEnabled: Bool

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
            hapticsEnabled: true
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

        let soundsEnabled = state.soundsEnabled
        let hapticsEnabled = state.hapticsEnabled
        state = TabataState(
            config: state.config,
            phase: .work,
            round: 1,
            phaseStartedAt: now,
            phaseDuration: state.config.workDuration,
            isRunning: true,
            pausedRemaining: nil,
            soundsEnabled: soundsEnabled,
            hapticsEnabled: hapticsEnabled
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
        state = .idle(config: state.config)
        state.soundsEnabled = soundsEnabled
        state.hapticsEnabled = hapticsEnabled
    }

    mutating func setSoundsEnabled(_ enabled: Bool) {
        state.soundsEnabled = enabled
    }

    mutating func setHapticsEnabled(_ enabled: Bool) {
        state.hapticsEnabled = enabled
    }

    mutating func tick(now: Date) -> TabataState {
        advance(now: now)
        return state
    }

    private mutating func advance(now: Date) {
        guard state.isRunning, state.isWorkoutPhase else {
            return
        }

        while state.isRunning, state.isWorkoutPhase {
            guard let startedAt = state.phaseStartedAt else {
                return
            }

            let elapsed = now.timeIntervalSince(startedAt)
            guard elapsed >= state.phaseDuration else {
                return
            }

            let nextStartedAt = startedAt.addingTimeInterval(state.phaseDuration)

            switch state.phase {
            case .work:
                state.phase = .rest
                state.phaseStartedAt = nextStartedAt
                state.phaseDuration = state.config.restDuration
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
        guard (state.soundsEnabled || state.hapticsEnabled), state.isRunning, state.isWorkoutPhase else {
            return nil
        }

        let second = Int(ceil(state.remaining(at: now)))
        let threshold = state.phase == .work ? 5 : 3

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
}

struct WatchCommandPayload: Codable, Sendable {
    var command: WatchCommand
    var soundsEnabled: Bool?
}

extension TabataState {
    func payloadDictionary() -> [String: Any] {
        CodablePayload.dictionary(from: self)
    }

    static func fromPayloadDictionary(_ dictionary: [String: Any]) -> TabataState? {
        CodablePayload.value(TabataState.self, from: dictionary)
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
