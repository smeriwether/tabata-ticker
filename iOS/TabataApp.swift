import SwiftUI

@main
struct TabataApp: App {
    private let viewModel = WorkoutViewModel()

    init() {
        viewModel.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
