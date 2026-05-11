import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var isShowingSettings = false
    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            if isShowingSettings {
                SettingsView(
                    soundsEnabled: Binding(
                        get: { viewModel.state.soundsEnabled },
                        set: { viewModel.setSoundsEnabled($0) }
                    ),
                    showsReset: showsReset,
                    reset: {
                        viewModel.reset()
                        withAnimation(.smooth(duration: 0.28)) {
                            isShowingSettings = false
                        }
                    },
                    close: {
                        withAnimation(.smooth(duration: 0.28)) {
                            isShowingSettings = false
                        }
                    }
                )
                .frame(maxWidth: contentMaxWidth)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                VStack(spacing: verticalSpacing) {
                    header

                    readout

                    Spacer(minLength: 18)

                    controls
                }
                .frame(maxWidth: contentMaxWidth)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.smooth(duration: 0.28), value: isShowingSettings)
        .onAppear {
            viewModel.activate()
        }
        .onReceive(ticker) { now in
            viewModel.tick(now: now)
        }
    }

    private var header: some View {
        HStack {
            Spacer()

            Button {
                withAnimation(.smooth(duration: 0.28)) {
                    isShowingSettings = true
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(settingsButtonFont)
                    .frame(width: settingsButtonSize, height: settingsButtonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .accessibilityLabel("Settings")
        }
    }

    private var readout: some View {
        VStack(spacing: readoutSpacing) {
            Text(stateTitle)
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)

            Text(timeText)
                .font(.system(size: timeSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.45)
                .lineLimit(1)

            Text(roundText)
                .font(roundFont)
                .foregroundStyle(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            primaryActionButton

            if showsReset {
                Button {
                    viewModel.reset()
                } label: {
                    Text("Reset")
                        .frame(maxWidth: .infinity, minHeight: resetButtonHeight)
                }
                .buttonStyle(.glass)
            }
        }
        .font(primaryButtonFont)
        .controlSize(.large)
        .frame(maxWidth: controlsMaxWidth)
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if isPrimaryButtonProminent {
            Button {
                primaryAction()
            } label: {
                Text(viewModel.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: primaryButtonHeight)
            }
            .buttonStyle(.glassProminent)
        } else {
            Button {
                primaryAction()
            } label: {
                Text(viewModel.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: primaryButtonHeight)
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
            return "Round \(viewModel.state.round) of \(viewModel.state.config.rounds)"
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

    private var contentMaxWidth: CGFloat? {
        horizontalSizeClass == .regular ? 720 : nil
    }

    private var controlsMaxWidth: CGFloat? {
        horizontalSizeClass == .regular ? 560 : 320
    }

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 48 : 20
    }

    private var verticalPadding: CGFloat {
        horizontalSizeClass == .regular ? 56 : 24
    }

    private var verticalSpacing: CGFloat {
        horizontalSizeClass == .regular ? 34 : 24
    }

    private var readoutSpacing: CGFloat {
        horizontalSizeClass == .regular ? 22 : 18
    }

    private var titleSize: CGFloat {
        horizontalSizeClass == .regular ? 64 : 50
    }

    private var timeSize: CGFloat {
        horizontalSizeClass == .regular ? 154 : 118
    }

    private var roundFont: Font {
        horizontalSizeClass == .regular ? .title.weight(.semibold) : .title2.weight(.semibold)
    }

    private var primaryButtonHeight: CGFloat {
        horizontalSizeClass == .regular ? 72 : 54
    }

    private var resetButtonHeight: CGFloat {
        horizontalSizeClass == .regular ? 60 : 48
    }

    private var primaryButtonFont: Font {
        horizontalSizeClass == .regular ? .title3.weight(.bold) : .headline.weight(.bold)
    }

    private var settingsButtonSize: CGFloat {
        horizontalSizeClass == .regular ? 52 : 34
    }

    private var settingsButtonFont: Font {
        horizontalSizeClass == .regular ? .title2.weight(.semibold) : .headline.weight(.semibold)
    }
}

private struct SettingsView: View {
    @Binding var soundsEnabled: Bool
    let showsReset: Bool
    let reset: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.86))
                .accessibilityLabel("Back")

                Spacer()
            }

            Text("Settings")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Toggle(isOn: $soundsEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Sounds")
                        .font(.headline)

                    Text(soundsEnabled ? "On" : "Off")
                        .font(.subheadline.weight(.semibold))
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
                    Text("Reset Workout")
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.glass)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            }
        }
    }
}
