import ActivityKit
import Foundation

@MainActor
final class TabataLiveActivityController {
    private var activity: Activity<TabataLiveActivityAttributes>?
    private var didReportRequestFailure = false

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

            // Requesting again on the next phase change is what lets an activity appear once the app
            // reaches the foreground, so only the first failure of an attempt is worth reporting.
            if !didReportRequestFailure {
                didReportRequestFailure = true
                TabataDiagnostics.report("Starting the Live Activity failed", error: error)
            }
        }
    }

    func end() {
        let activityIDs = Activity<TabataLiveActivityAttributes>.activities.map(\.id)
        activity = nil
        didReportRequestFailure = false

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
        let tint = presentation.background.start
        let phaseDuration = max(1, state.phaseDuration)

        title = presentation.title
        roundText = "\(state.round)/\(state.config.rounds)"
        isRunning = state.isRunning
        phaseIconName = state.isRunning && state.phase == .work ? "bolt.fill" : "pause.fill"

        // The exact phase boundaries, not a rounded remaining count, because the system renders the
        // countdown from these dates. A paused phase is frozen by pointing pausedAt at this moment.
        if state.isRunning, let phaseStartedAt = state.phaseStartedAt {
            startsAt = phaseStartedAt
            endsAt = phaseStartedAt.addingTimeInterval(phaseDuration)
            pausedAt = nil
        } else {
            let phaseEnd = now.addingTimeInterval(state.remaining(at: now))
            startsAt = phaseEnd.addingTimeInterval(-phaseDuration)
            endsAt = phaseEnd
            pausedAt = now
        }

        workoutEndsAt = now.addingTimeInterval(Self.workoutRemainingDuration(for: state, now: now))
        tintRed = tint.red
        tintGreen = tint.green
        tintBlue = tint.blue
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
                + TimeInterval(max(0, state.config.rounds - state.round)) * fullFutureRoundDuration
        case .rest:
            return phaseRemaining
                + TimeInterval(max(0, state.config.rounds - state.round)) * state.config.workDuration
                + TimeInterval(max(0, state.config.rounds - state.round - 1)) * state.config.restDuration
        case .idle, .countdown, .complete:
            return 0
        }
    }
}
