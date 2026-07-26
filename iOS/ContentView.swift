import SwiftUI

private enum ContentRoute: Hashable {
    case settings
    case createPreset
    case editPreset(String)

    var presetID: String? {
        switch self {
        case .settings, .createPreset:
            nil
        case .editPreset(let presetID):
            presetID
        }
    }

    var title: String {
        switch self {
        case .settings:
            "Settings"
        case .createPreset:
            "New Preset"
        case .editPreset:
            "Edit Preset"
        }
    }

    var saveTitle: String {
        switch self {
        case .settings:
            ""
        case .createPreset:
            "Create Preset"
        case .editPreset:
            "Save Preset"
        }
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let viewModel: WorkoutViewModel
    @State private var path: [ContentRoute] = []

    // Required rather than defaulted: a default would quietly build a second view model, and with it
    // a second engine and a second WatchConnectivity delegate.
    init(viewModel: WorkoutViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: metrics.verticalSpacing) {
                    header

                    readout

                    Spacer(minLength: 18)

                    controls
                }
                .frame(maxWidth: metrics.contentMaxWidth)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, metrics.verticalPadding)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: ContentRoute.self) { route in
                screen(for: route)
            }
        }
        .tint(.white.opacity(0.86))
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.activate()
        }
    }

    @ViewBuilder
    private func screen(for route: ContentRoute) -> some View {
        switch route {
        case .settings:
            settingsScreen
        case .createPreset, .editPreset:
            presetEditorScreen(for: route)
        }
    }

    private var settingsScreen: some View {
        ZStack {
            LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            SettingsView(
                soundsEnabled: Binding(
                    get: { viewModel.state.settings.soundsEnabled },
                    set: { viewModel.setSoundsEnabled($0) }
                ),
                hapticsEnabled: Binding(
                    get: { viewModel.state.settings.hapticsEnabled },
                    set: { viewModel.setHapticsEnabled($0) }
                ),
                startCountdownEnabled: Binding(
                    get: { viewModel.state.settings.startCountdownEnabled },
                    set: { viewModel.setStartCountdownEnabled($0) }
                ),
                presets: viewModel.presets,
                canManageCustomPresets: viewModel.canManageCustomPresets,
                onEditPreset: { preset in
                    path.append(.editPreset(preset.id))
                },
                onDeletePreset: { preset in
                    viewModel.deletePreset(id: preset.id)
                }
            )
            .frame(maxWidth: metrics.contentMaxWidth)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func presetEditorScreen(for route: ContentRoute) -> some View {
        let preset = route.presetID.flatMap { id in viewModel.presets.first { $0.id == id } }
        let initialConfig = preset?.config ?? .classic

        return ZStack {
            LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            PresetEditorView(
                title: route.title,
                saveTitle: route.saveTitle,
                initialConfig: initialConfig,
                initialName: preset?.customName,
                existingPresetID: preset?.id,
                canCreatePreset: viewModel.canCreatePreset,
                onSave: { config, name in
                    let didSave: Bool
                    switch route {
                    case .settings:
                        didSave = false
                    case .createPreset:
                        didSave = viewModel.createPreset(config: config, name: name)
                    case .editPreset(let presetID):
                        didSave = viewModel.updatePreset(id: presetID, config: config, name: name)
                    }

                    if didSave {
                        path.removeLast()
                    }
                    return didSave
                }
            )
            .frame(maxWidth: metrics.contentMaxWidth)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            if viewModel.state.phase == .idle {
                presetMenu
            }

            Spacer()

            Button {
                withAnimation(.smooth(duration: 0.28)) {
                    path.append(.settings)
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(metrics.settingsButtonFont)
                    .frame(width: metrics.settingsButtonSize, height: metrics.settingsButtonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .accessibilityLabel("Settings")
        }
    }

    private var presetMenu: some View {
        Menu {
            ForEach(viewModel.presets) { preset in
                Button {
                    viewModel.selectPreset(preset)
                } label: {
                    Label(preset.name, systemImage: preset.id == viewModel.selectedPreset.id ? "checkmark" : "timer")
                }
            }

            if viewModel.canCreatePreset {
                Divider()

                Button {
                    path.append(.createPreset)
                } label: {
                    Label("New Preset", systemImage: "plus")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.headline.weight(.bold))

                Text(viewModel.selectedPreset.name)
                    .font(.headline.weight(.bold))
                    .monospacedDigit()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .frame(minWidth: 116, minHeight: metrics.settingsButtonSize)
            .contentShape(Capsule())
        }
        .buttonStyle(.glass)
        .foregroundStyle(glassControlForeground)
        .accessibilityLabel("Preset")
        .accessibilityValue(viewModel.selectedPreset.name)
    }

    private var readout: some View {
        VStack(spacing: metrics.readoutSpacing) {
            Text(presentation.title)
                .font(.system(size: metrics.titleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)

            Text(timeText)
                .font(.system(size: metrics.timeSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.45)
                .lineLimit(1)

            Text(presentation.phoneRoundText)
                .font(metrics.roundFont)
                .foregroundStyle(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            primaryActionButton

            if presentation.showsReset {
                Button {
                    viewModel.reset()
                } label: {
                    Text("Reset")
                        .frame(maxWidth: .infinity, minHeight: metrics.resetButtonHeight)
                }
                .buttonStyle(.glassProminent)
                .foregroundStyle(.black)
            }
        }
        .font(metrics.primaryButtonFont)
        .controlSize(.large)
        .frame(maxWidth: metrics.controlsMaxWidth)
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if isPaused {
            Button {
                primaryAction()
            } label: {
                Text(presentation.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: metrics.primaryButtonHeight)
            }
            .buttonStyle(.glassProminent)
            .tint(resumeButtonTint)
            .foregroundStyle(.white)
        } else if isPrimaryButtonProminent {
            Button {
                primaryAction()
            } label: {
                Text(presentation.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: metrics.primaryButtonHeight)
            }
            .buttonStyle(.glassProminent)
            .foregroundStyle(.black)
        } else {
            Button {
                primaryAction()
            } label: {
                Text(presentation.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: metrics.primaryButtonHeight)
            }
            .buttonStyle(.glass)
            .foregroundStyle(glassControlForeground)
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

    private var isPaused: Bool {
        viewModel.state.isWorkoutPhase && !viewModel.state.isRunning
    }

    private var metrics: TimerMetrics {
        TimerMetrics(horizontalSizeClass: horizontalSizeClass)
    }

    private var presentation: TabataPresentation {
        TabataPresentation(state: viewModel.state)
    }

    private var timeText: String {
        let remaining = Int(ceil(viewModel.state.remaining(at: viewModel.now)))
        return Self.timeText(for: max(0, remaining))
    }

    private static func timeText(for seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var backgroundColors: [Color] {
        [Color(presentation.background.start), Color(presentation.background.end)]
    }

    private var resumeButtonTint: Color {
        Color(red: 0.00, green: 0.48, blue: 0.95)
    }
}
