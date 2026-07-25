import AppIntents

// Siri and Shortcuts run these in the app process, launching it in the background when needed, so a
// workout can be started without unlocking the phone or leaving the exercise.
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription("Starts a workout using the selected preset.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let didStart = await MainActor.run { () -> Bool in
            let workout = WorkoutViewModel.shared()
            workout.activate()

            guard workout.state.phase == .idle || workout.state.phase == .complete else {
                return false
            }

            workout.start()
            return true
        }

        return .result(dialog: didStart ? "Starting your workout." : "A workout is already running.")
    }
}

struct PauseWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Workout"
    static let description = IntentDescription("Pauses the workout that is currently running.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let didPause = await MainActor.run { () -> Bool in
            let workout = WorkoutViewModel.shared()
            workout.activate()

            guard workout.state.isWorkoutPhase, workout.state.isRunning else {
                return false
            }

            workout.pause()
            return true
        }

        return .result(dialog: didPause ? "Workout paused." : "No workout is running.")
    }
}

struct ResumeWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Workout"
    static let description = IntentDescription("Resumes a paused workout.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let didResume = await MainActor.run { () -> Bool in
            let workout = WorkoutViewModel.shared()
            workout.activate()

            guard workout.state.isWorkoutPhase, !workout.state.isRunning else {
                return false
            }

            workout.resume()
            return true
        }

        return .result(dialog: didResume ? "Workout resumed." : "No workout is paused.")
    }
}

struct TabataShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout with \(.applicationName)",
                "Start a Tabata with \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "play.fill"
        )

        AppShortcut(
            intent: PauseWorkoutIntent(),
            phrases: [
                "Pause my workout with \(.applicationName)",
                "Pause \(.applicationName)"
            ],
            shortTitle: "Pause Workout",
            systemImageName: "pause.fill"
        )

        AppShortcut(
            intent: ResumeWorkoutIntent(),
            phrases: [
                "Resume my workout with \(.applicationName)",
                "Resume \(.applicationName)"
            ],
            shortTitle: "Resume Workout",
            systemImageName: "playpause.fill"
        )

        AppShortcut(
            intent: EndWorkoutIntent(),
            phrases: [
                "End my workout with \(.applicationName)",
                "Stop my workout with \(.applicationName)"
            ],
            shortTitle: "End Workout",
            systemImageName: "xmark"
        )
    }
}
