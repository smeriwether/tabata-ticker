import SwiftUI

struct WatchContentView: View {
    @State private var viewModel = WatchWorkoutViewModel()
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            Group {
                if isShowingSettings {
                    WatchSettingsView(
                        soundsEnabled: Binding(
                            get: { viewModel.state.soundsEnabled },
                            set: { viewModel.setSoundsEnabled($0) }
                        ),
                        showsReset: presentation.showsReset,
                        reset: {
                            viewModel.reset()
                            withAnimation(.smooth(duration: 0.22)) {
                                isShowingSettings = false
                            }
                        },
                        close: {
                            withAnimation(.smooth(duration: 0.22)) {
                                isShowingSettings = false
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else {
                    VStack(spacing: 7) {
                        HStack {
                            Spacer()

                            Button {
                                withAnimation(.smooth(duration: 0.22)) {
                                    isShowingSettings = true
                                }
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 24, height: 24)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white.opacity(0.86))
                            .accessibilityLabel("Settings")
                        }

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
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 8)
        }
        .animation(.smooth(duration: 0.22), value: isShowingSettings)
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

private struct WatchSettingsView: View {
    @Binding var soundsEnabled: Bool
    let showsReset: Bool
    let reset: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.86))
                .accessibilityLabel("Back")

                Spacer()
            }

            Text("Settings")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Toggle(isOn: $soundsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Sounds")
                        .font(.caption.weight(.semibold))

                    Text(soundsEnabled ? "On" : "Off")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .tint(.green)
            .foregroundStyle(.white)

            Spacer(minLength: 0)

            if showsReset {
                Button {
                    reset()
                } label: {
                    Text("Reset")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.glass)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            }
        }
    }
}

private extension Color {
    init(_ tabataColor: TabataColor) {
        self.init(red: tabataColor.red, green: tabataColor.green, blue: tabataColor.blue)
    }
}
