import ActivityKit
import Foundation

@MainActor
final class TabataLiveActivityController {
    private var activity: Activity<TabataLiveActivityAttributes>?

    func sync(state: TabataState, now: Date) {
        guard state.isWorkoutPhase else {
            end()
            return
        }

        let contentState = TabataLiveActivityAttributes.ContentState(state: state, now: now)
        let content = ActivityContent(
            state: contentState,
            staleDate: contentState.isRunning ? contentState.workoutEndsAt : nil,
            relevanceScore: contentState.isRunning ? 1 : 0.5
        )

        if let existingActivity = activity ?? Activity<TabataLiveActivityAttributes>.activities.first {
            activity = existingActivity
            let activityID = existingActivity.id
            Task.detached { [activityID, content] in
                guard let activity = Activity<TabataLiveActivityAttributes>.activities.first(where: { $0.id == activityID }) else {
                    return
                }

                await activity.update(content)
            }
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        do {
            activity = try Activity.request(
                attributes: TabataLiveActivityAttributes(workoutName: "Tabata"),
                content: content,
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func end() {
        let activityIDs = Activity<TabataLiveActivityAttributes>.activities.map(\.id)
        activity = nil

        guard !activityIDs.isEmpty else {
            return
        }

        Task.detached { [activityIDs] in
            for activity in Activity<TabataLiveActivityAttributes>.activities where activityIDs.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

private extension TabataLiveActivityAttributes.ContentState {
    init(state: TabataState, now: Date) {
        let presentation = TabataPresentation(state: state)
        let phaseRemaining = Int(ceil(state.remaining(at: now)))
        let tint = presentation.background.start

        title = presentation.title
        roundText = "\(state.round)/\(state.config.rounds)"
        symbol = Self.symbol(for: state)
        isRunning = state.isRunning
        phase = state.phase.rawValue
        round = state.round
        totalRounds = state.config.rounds
        workDurationSeconds = max(1, Int(ceil(state.config.workDuration)))
        restDurationSeconds = max(1, Int(ceil(state.config.restDuration)))
        startsAt = state.phaseStartedAt ?? now
        endsAt = now.addingTimeInterval(TimeInterval(phaseRemaining))
        workoutEndsAt = now.addingTimeInterval(Self.workoutRemainingDuration(for: state, now: now))
        remainingSeconds = phaseRemaining
        phaseDurationSeconds = max(1, Int(ceil(state.phaseDuration)))
        tintRed = tint.red
        tintGreen = tint.green
        tintBlue = tint.blue
    }

    private static func symbol(for state: TabataState) -> String {
        if !state.isRunning {
            return "II"
        }

        switch state.phase {
        case .work:
            return "W"
        case .rest:
            return "R"
        case .idle, .complete:
            return "T"
        }
    }

    private static func workoutRemainingDuration(for state: TabataState, now: Date) -> TimeInterval {
        guard state.isRunning, state.isWorkoutPhase else {
            return state.remaining(at: now)
        }

        let phaseRemaining = state.remaining(at: now)
        let fullFutureRoundDuration = state.config.workDuration + state.config.restDuration

        switch state.phase {
        case .work:
            return phaseRemaining
                + state.config.restDuration
                + TimeInterval(max(0, state.config.rounds - state.round)) * fullFutureRoundDuration
        case .rest:
            return phaseRemaining
                + TimeInterval(max(0, state.config.rounds - state.round)) * fullFutureRoundDuration
        case .idle, .complete:
            return 0
        }
    }
}
