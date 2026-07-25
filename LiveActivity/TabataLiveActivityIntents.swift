import AppIntents

// A LiveActivityIntent runs inside the app's process, launching it in the background when it is not
// already running. The widget extension compiles these types so it can build the buttons, but only
// the app target defines TABATA_APP, since the view model does not exist in the extension.
struct ToggleWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or Resume Workout"
    static let description = IntentDescription("Pauses a running workout, or resumes a paused one.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        #if TABATA_APP
        await MainActor.run {
            let workout = WorkoutViewModel.shared()
            workout.activate()
            workout.toggleRunning()
        }
        #endif

        return .result()
    }
}

struct EndWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Workout"
    static let description = IntentDescription("Ends the current workout and returns the timer to the start.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        #if TABATA_APP
        await MainActor.run {
            let workout = WorkoutViewModel.shared()
            workout.activate()
            workout.reset()
        }
        #endif

        return .result()
    }
}
