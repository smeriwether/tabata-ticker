import ActivityKit
import Foundation

struct TabataLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var title: String
        var roundText: String
        var symbol: String
        var isRunning: Bool
        var startsAt: Date
        var endsAt: Date
        var remainingSeconds: Int
        var phaseDurationSeconds: Int
        var tintRed: Double
        var tintGreen: Double
        var tintBlue: Double
    }

    var workoutName: String
}

extension TabataLiveActivityAttributes.ContentState {
    var timerInterval: ClosedRange<Date> {
        startsAt...max(startsAt, endsAt)
    }

    var remainingText: String {
        let seconds = max(0, remainingSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var elapsedFraction: Double {
        let duration = max(1, phaseDurationSeconds)
        return min(1, max(0, 1 - (Double(remainingSeconds) / Double(duration))))
    }
}
