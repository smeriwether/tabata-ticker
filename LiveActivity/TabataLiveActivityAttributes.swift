import ActivityKit
import Foundation

struct TabataLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var title: String
        var roundText: String
        var symbol: String
        var isRunning: Bool
        var updatedAt: Date
        var endsAt: Date
        var remainingSeconds: Int
        var tintRed: Double
        var tintGreen: Double
        var tintBlue: Double
    }

    var workoutName: String
}

extension TabataLiveActivityAttributes.ContentState {
    var timerInterval: ClosedRange<Date> {
        updatedAt...max(updatedAt, endsAt)
    }

    var remainingText: String {
        let seconds = max(0, remainingSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
