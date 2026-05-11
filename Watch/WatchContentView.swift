import SwiftUI

struct WatchContentView: View {
    @StateObject private var viewModel = WatchWorkoutViewModel()
    @State private var isShowingSettings = false
    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

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
                        showsReset: showsReset,
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

                        Text(stateTitle)
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(timeText)
                            .font(.system(size: 55, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Text(roundText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        HStack(spacing: 6) {
                            primaryActionButton

                            if showsReset {
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
        .onReceive(ticker) { now in
            viewModel.tick(now: now)
        }
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if isPrimaryButtonProminent {
            Button {
                primaryAction()
            } label: {
                Text(viewModel.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glassProminent)
        } else {
            Button {
                primaryAction()
            } label: {
                Text(viewModel.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glass)
            .foregroundStyle(.black)
        }
    }

    private func primaryAction() {
        if viewModel.state.phase == .complete {
            viewModel.reset()
        } else {
            viewModel.toggleRunning()
        }
    }

    private var isPrimaryButtonProminent: Bool {
        viewModel.state.phase == .idle || viewModel.state.phase == .complete || isPaused
    }

    private var showsReset: Bool {
        isPaused
    }

    private var isPaused: Bool {
        viewModel.state.isWorkoutPhase && !viewModel.state.isRunning
    }

    private var stateTitle: String {
        if viewModel.state.isWorkoutPhase, !viewModel.state.isRunning {
            return "PAUSED"
        }

        switch viewModel.state.phase {
        case .idle:
            return "Tabata"
        case .work:
            return "WORK"
        case .rest:
            return "REST"
        case .complete:
            return "DONE"
        }
    }

    private var timeText: String {
        let remaining = Int(ceil(viewModel.state.remaining(at: Date())))
        return String(format: "0:%02d", max(0, remaining))
    }

    private var roundText: String {
        switch viewModel.state.phase {
        case .idle:
            return "8 rounds"
        case .complete:
            return "Complete"
        case .work, .rest:
            return "\(viewModel.state.round) / \(viewModel.state.config.rounds)"
        }
    }

    private var backgroundColors: [Color] {
        if viewModel.state.isWorkoutPhase, !viewModel.state.isRunning {
            return [
                Color(red: 0.24, green: 0.24, blue: 0.27),
                Color(red: 0.10, green: 0.11, blue: 0.13)
            ]
        }

        switch viewModel.state.phase {
        case .idle:
            return [
                Color(red: 0.03, green: 0.52, blue: 0.50),
                Color(red: 0.18, green: 0.24, blue: 0.72)
            ]
        case .work:
            return [
                Color(red: 0.92, green: 0.48, blue: 0.12),
                Color(red: 0.70, green: 0.30, blue: 0.06)
            ]
        case .rest:
            return [
                Color(red: 0.00, green: 0.48, blue: 0.95),
                Color(red: 0.04, green: 0.24, blue: 0.78)
            ]
        case .complete:
            return [
                Color(red: 0.08, green: 0.64, blue: 0.40),
                Color(red: 0.04, green: 0.38, blue: 0.29)
            ]
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
