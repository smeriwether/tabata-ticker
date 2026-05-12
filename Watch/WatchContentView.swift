import SwiftUI

struct WatchContentView: View {
    @State private var viewModel = WatchWorkoutViewModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text(presentation.title)
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(timeText)
                    .font(.system(size: 55, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(presentation.watchRoundText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer(minLength: 10)

                HStack(spacing: 6) {
                    primaryActionButton

                    if presentation.showsReset {
                        Button {
                            viewModel.reset()
                        } label: {
                            Text("Reset")
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.glass)
                    }
                }
                .font(.caption.weight(.bold))
                .controlSize(.small)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 8)
            .padding(.top, 18)
            .padding(.bottom, 8)
        }
        .onAppear {
            viewModel.activate()
        }
        .task(id: viewModel.state.isRunning) {
            await tickWhileRunning()
        }
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if isPrimaryButtonProminent {
            Button {
                primaryAction()
            } label: {
                Text(presentation.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glassProminent)
        } else {
            Button {
                primaryAction()
            } label: {
                Text(presentation.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glass)
            .foregroundStyle(.black)
        }
    }

    private func primaryAction() {
        if presentation.primaryAction == .reset {
            viewModel.reset()
        } else {
            viewModel.toggleRunning()
        }
    }

    private var isPrimaryButtonProminent: Bool {
        presentation.isPrimaryButtonProminent
    }

    private var presentation: TabataPresentation {
        TabataPresentation(state: viewModel.state)
    }

    private var timeText: String {
        let remaining = Int(ceil(viewModel.state.remaining(at: viewModel.now)))
        return String(format: "0:%02d", max(0, remaining))
    }

    private var backgroundColors: [Color] {
        [Color(presentation.background.start), Color(presentation.background.end)]
    }

    @MainActor
    private func tickWhileRunning() async {
        guard viewModel.state.isRunning else {
            return
        }

        while !Task.isCancelled, viewModel.state.isRunning {
            viewModel.tick(now: Date())
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }
}

private extension Color {
    init(_ tabataColor: TabataColor) {
        self.init(red: tabataColor.red, green: tabataColor.green, blue: tabataColor.blue)
    }
}
