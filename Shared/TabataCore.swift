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

    static func idle(config: TabataConfig = .classic) -> TabataState {
        TabataState(
            config: config,
            phase: .idle,
            round: 0,
            phaseStartedAt: nil,
            phaseDuration: config.workDuration,
            isRunning: false,
            pausedRemaining: config.workDuration,
            soundsEnabled: true
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
        state = TabataState(
            config: state.config,
            phase: .work,
            round: 1,
            phaseStartedAt: now,
            phaseDuration: state.config.workDuration,
            isRunning: true,
            pausedRemaining: nil,
            soundsEnabled: soundsEnabled
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
        state = .idle(config: state.config)
        state.soundsEnabled = soundsEnabled
    }

    mutating func setSoundsEnabled(_ enabled: Bool) {
        state.soundsEnabled = enabled
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
        guard state.soundsEnabled, state.isRunning, state.isWorkoutPhase else {
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
        guard newState.soundsEnabled else {
            return false
        }

        if oldState.phase == .idle, newState.phase == .work {
            return false
        }

        return oldState.phase != newState.phase || oldState.round != newState.round
    }
}

enum WatchCommand: String, Codable, Sendable {
    case toggleRunning
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
