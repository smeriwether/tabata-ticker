import ActivityKit
import Foundation

struct TabataLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var title: String
        var roundText: String
        var symbol: String
        var isRunning: Bool
        var phase: String
        var round: Int
        var totalRounds: Int
        var workDurationSeconds: Int
        var restDurationSeconds: Int
        var startsAt: Date
        var endsAt: Date
        var workoutEndsAt: Date
        var remainingSeconds: Int
        var phaseDurationSeconds: Int
        var tintRed: Double
        var tintGreen: Double
        var tintBlue: Double
    }

    var workoutName: String
}

struct TabataLiveActivityDisplayState: Equatable {
    var title: String
    var roundText: String
    var statusText: String
    var phaseIconName: String
    var startsAt: Date
    var endsAt: Date
    var remainingSeconds: Int
    var phaseDurationSeconds: Int
    var tintRed: Double
    var tintGreen: Double
    var tintBlue: Double
}

extension TabataLiveActivityAttributes.ContentState {
    func displayState(at date: Date) -> TabataLiveActivityDisplayState {
        guard isRunning else {
            return staticDisplayState(statusText: "Paused", phaseIconName: "pause.fill")
        }

        let workSeconds = max(1, workDurationSeconds)
        let restSeconds = max(1, restDurationSeconds)
        let totalRounds = max(1, totalRounds)
        var displayPhase = phase == "rest" ? "rest" : "work"
        var displayRound = min(max(1, round), totalRounds)
        var phaseStart = startsAt
        var phaseDuration = Self.duration(for: displayPhase, workSeconds: workSeconds, restSeconds: restSeconds)

        while date.timeIntervalSince(phaseStart) >= TimeInterval(phaseDuration) {
            phaseStart = phaseStart.addingTimeInterval(TimeInterval(phaseDuration))

            if displayPhase == "work" {
                displayPhase = "rest"
                phaseDuration = restSeconds
            } else if displayRound < totalRounds {
                displayRound += 1
                displayPhase = "work"
                phaseDuration = workSeconds
            } else {
                return completeDisplayState()
            }
        }

        let elapsed = max(0, date.timeIntervalSince(phaseStart))
        let remainingSeconds = max(0, Int(ceil(TimeInterval(phaseDuration) - elapsed)))
        let tint = Self.tintComponents(for: displayPhase)

        return TabataLiveActivityDisplayState(
            title: displayPhase == "work" ? "WORK" : "REST",
            roundText: "\(displayRound) / \(totalRounds)",
            statusText: "Active",
            phaseIconName: displayPhase == "work" ? "bolt.fill" : "pause.fill",
            startsAt: phaseStart,
            endsAt: phaseStart.addingTimeInterval(TimeInterval(phaseDuration)),
            remainingSeconds: remainingSeconds,
            phaseDurationSeconds: phaseDuration,
            tintRed: tint.red,
            tintGreen: tint.green,
            tintBlue: tint.blue
        )
    }
}

extension TabataLiveActivityDisplayState {
    var remainingText: String {
        let seconds = max(0, remainingSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var elapsedFraction: Double {
        let duration = max(1, phaseDurationSeconds)
        return min(1, max(0, 1 - (Double(remainingSeconds) / Double(duration))))
    }
}

private extension TabataLiveActivityAttributes.ContentState {
    func staticDisplayState(statusText: String, phaseIconName: String) -> TabataLiveActivityDisplayState {
        TabataLiveActivityDisplayState(
            title: title,
            roundText: roundText.replacingOccurrences(of: "/", with: " / "),
            statusText: statusText,
            phaseIconName: phaseIconName,
            startsAt: startsAt,
            endsAt: endsAt,
            remainingSeconds: max(0, remainingSeconds),
            phaseDurationSeconds: max(1, phaseDurationSeconds),
            tintRed: tintRed,
            tintGreen: tintGreen,
            tintBlue: tintBlue
        )
    }

    func completeDisplayState() -> TabataLiveActivityDisplayState {
        let tint = Self.tintComponents(for: "complete")
        return TabataLiveActivityDisplayState(
            title: "DONE",
            roundText: "\(max(1, totalRounds)) / \(max(1, totalRounds))",
            statusText: "Done",
            phaseIconName: "checkmark",
            startsAt: workoutEndsAt,
            endsAt: workoutEndsAt,
            remainingSeconds: 0,
            phaseDurationSeconds: 1,
            tintRed: tint.red,
            tintGreen: tint.green,
            tintBlue: tint.blue
        )
    }

    static func duration(for phase: String, workSeconds: Int, restSeconds: Int) -> Int {
        phase == "rest" ? restSeconds : workSeconds
    }

    static func tintComponents(for phase: String) -> (red: Double, green: Double, blue: Double) {
        switch phase {
        case "rest":
            return (0.00, 0.48, 0.95)
        case "complete":
            return (0.08, 0.64, 0.40)
        default:
            return (0.92, 0.48, 0.12)
        }
    }
}
