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

    init(viewModel: WorkoutViewModel = WorkoutViewModel()) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: verticalSpacing) {
                    header

                    readout

                    Spacer(minLength: 18)

                    controls
                }
                .frame(maxWidth: contentMaxWidth)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: ContentRoute.self) { route in
                screen(for: route)
            }
        }
        .tint(.white.opacity(0.86))
        .onAppear {
            viewModel.activate()
        }
        .task(id: viewModel.state.isRunning) {
            await tickWhileRunning()
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
                    get: { viewModel.state.soundsEnabled },
                    set: { viewModel.setSoundsEnabled($0) }
                ),
                hapticsEnabled: Binding(
                    get: { viewModel.state.hapticsEnabled },
                    set: { viewModel.setHapticsEnabled($0) }
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
            .frame(maxWidth: contentMaxWidth)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
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
                existingPresetID: preset?.id,
                canCreatePreset: viewModel.canCreatePreset,
                onSave: { config in
                    let didSave: Bool
                    switch route {
                    case .settings:
                        didSave = false
                    case .createPreset:
                        didSave = viewModel.createPreset(config: config)
                    case .editPreset(let presetID):
                        didSave = viewModel.updatePreset(id: presetID, config: config)
                    }

                    if didSave {
                        path.removeLast()
                    }
                    return didSave
                }
            )
            .frame(maxWidth: contentMaxWidth)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
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
                    .font(settingsButtonFont)
                    .frame(width: settingsButtonSize, height: settingsButtonSize)
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
                    Label {
                        Text(preset.name)
                            .foregroundStyle(presetControlForeground)
                    } icon: {
                        Image(systemName: preset.id == viewModel.selectedPreset.id ? "checkmark" : "timer")
                            .foregroundStyle(presetControlForeground)
                    }
                }
            }

            if viewModel.canCreatePreset {
                Divider()

                Button {
                    path.append(.createPreset)
                } label: {
                    Label {
                        Text("New Preset")
                            .foregroundStyle(presetControlForeground)
                    } icon: {
                        Image(systemName: "plus")
                            .foregroundStyle(presetControlForeground)
                    }
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
            .frame(minWidth: 116, minHeight: settingsButtonSize)
            .contentShape(Capsule())
        }
        .buttonStyle(.glass)
        .foregroundStyle(presetControlForeground)
        .tint(presetControlForeground)
        .accessibilityLabel("Preset")
    }

    private var readout: some View {
        VStack(spacing: readoutSpacing) {
            Text(presentation.title)
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)

            Text(timeText)
                .font(.system(size: timeSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.45)
                .lineLimit(1)

            Text(presentation.phoneRoundText)
                .font(roundFont)
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
                        .frame(maxWidth: .infinity, minHeight: resetButtonHeight)
                }
                .buttonStyle(.glassProminent)
                .foregroundStyle(.black)
            }
        }
        .font(primaryButtonFont)
        .controlSize(.large)
        .frame(maxWidth: controlsMaxWidth)
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if isPaused {
            Button {
                primaryAction()
            } label: {
                Text(presentation.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: primaryButtonHeight)
            }
            .buttonStyle(.glassProminent)
            .tint(resumeButtonTint)
            .foregroundStyle(.white)
        } else if isPrimaryButtonProminent {
            Button {
                primaryAction()
            } label: {
                Text(presentation.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: primaryButtonHeight)
            }
            .buttonStyle(.glassProminent)
            .foregroundStyle(.black)
        } else {
            Button {
                primaryAction()
            } label: {
                Text(presentation.primaryButtonTitle)
                    .frame(maxWidth: .infinity, minHeight: primaryButtonHeight)
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

    private var isPaused: Bool {
        viewModel.state.isWorkoutPhase && !viewModel.state.isRunning
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

    private var presetControlForeground: Color {
        Color(red: 0.05, green: 0.22, blue: 0.28)
    }

    private var resumeButtonTint: Color {
        Color(red: 0.00, green: 0.48, blue: 0.95)
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
        horizontalSizeClass == .regular ? 52 : 44
    }

    private var settingsButtonFont: Font {
        horizontalSizeClass == .regular ? .title2.weight(.semibold) : .title3.weight(.semibold)
    }
}

private struct SettingsView: View {
    @Binding var soundsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    let presets: [TabataPreset]
    let canManageCustomPresets: Bool
    let onEditPreset: (TabataPreset) -> Void
    let onDeletePreset: (TabataPreset) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
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

                Toggle(isOn: $hapticsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Haptic feedback on Apple Watch")
                            .font(.headline)

                        Text(hapticsEnabled ? "On" : "Off")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .tint(.green)
                .foregroundStyle(.white)

                PresetSettingsSection(
                    presets: presets,
                    canManageCustomPresets: canManageCustomPresets,
                    onEditPreset: onEditPreset,
                    onDeletePreset: onDeletePreset
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PresetSettingsSection: View {
    let presets: [TabataPreset]
    let canManageCustomPresets: Bool
    let onEditPreset: (TabataPreset) -> Void
    let onDeletePreset: (TabataPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.headline.weight(.black))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.14), in: Circle())

                Text("Presets")
                    .font(.title2.weight(.black))
            }
            .foregroundStyle(.white)

            VStack(spacing: 0) {
                ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                    PresetSettingsRow(
                        preset: preset,
                        canManageCustomPresets: canManageCustomPresets,
                        onEdit: {
                            onEditPreset(preset)
                        },
                        onDelete: {
                            onDeletePreset(preset)
                        }
                    )
                    .padding(.vertical, 10)

                    if index < presets.count - 1 {
                        Divider()
                            .overlay(.white.opacity(0.18))
                    }
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct PresetSettingsRow: View {
    let preset: TabataPreset
    let canManageCustomPresets: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.title3.weight(.black))
                    .monospacedDigit()

                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 12)

            if preset.isDefault {
                Image(systemName: "lock.fill")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Default preset")
            } else if canManageCustomPresets {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.headline.weight(.bold))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(presetActionForeground)
                    .accessibilityLabel("Edit \(preset.name)")

                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.headline.weight(.bold))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(presetActionForeground)
                    .accessibilityLabel("Delete \(preset.name)")
                    .confirmationDialog("Delete preset?", isPresented: $isConfirmingDelete) {
                        Button("Delete \(preset.name)", role: .destructive, action: onDelete)
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("\(preset.name) will be removed permanently.")
                    }
                }
            } else {
                Image(systemName: "lock.fill")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Preset changes unavailable during workout")
            }
        }
        .foregroundStyle(.white)
    }

    private var statusText: String {
        if preset.isDefault {
            return "Default"
        }
        return "Custom"
    }

    private var presetActionForeground: Color {
        Color(red: 0.05, green: 0.22, blue: 0.28)
    }
}

private struct PresetEditorView: View {
    private static let workRange = 5...300
    private static let restRange = 5...300
    private static let roundsRange = 1...30

    let title: String
    let saveTitle: String
    let existingPresetID: String?
    let canCreatePreset: Bool
    let onSave: (TabataConfig) -> Bool

    @State private var workSeconds: Int
    @State private var restSeconds: Int
    @State private var rounds: Int
    @State private var showsSaveError = false

    init(
        title: String,
        saveTitle: String,
        initialConfig: TabataConfig,
        existingPresetID: String?,
        canCreatePreset: Bool,
        onSave: @escaping (TabataConfig) -> Bool
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.existingPresetID = existingPresetID
        self.canCreatePreset = canCreatePreset
        self.onSave = onSave
        _workSeconds = State(initialValue: Self.clamped(initialConfig.workSeconds, to: Self.workRange))
        _restSeconds = State(initialValue: Self.clamped(initialConfig.restSeconds, to: Self.restRange))
        _rounds = State(initialValue: Self.clamped(initialConfig.rounds, to: Self.roundsRange))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 44, weight: .black, design: .rounded))

                Text(config.presetName)
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)

            VStack(spacing: 16) {
                PresetValueControl(
                    title: "Work Time",
                    value: "\(workSeconds) sec",
                    decrementDisabled: workSeconds <= Self.workRange.lowerBound,
                    incrementDisabled: workSeconds >= Self.workRange.upperBound,
                    onDecrement: {
                        adjustWork(by: -5)
                    },
                    onIncrement: {
                        adjustWork(by: 5)
                    }
                )

                PresetValueControl(
                    title: "Rest Time",
                    value: "\(restSeconds) sec",
                    decrementDisabled: restSeconds <= Self.restRange.lowerBound,
                    incrementDisabled: restSeconds >= Self.restRange.upperBound,
                    onDecrement: {
                        adjustRest(by: -5)
                    },
                    onIncrement: {
                        adjustRest(by: 5)
                    }
                )

                PresetValueControl(
                    title: "Rounds",
                    value: "\(rounds) \(rounds == 1 ? "round" : "rounds")",
                    decrementDisabled: rounds <= Self.roundsRange.lowerBound,
                    incrementDisabled: rounds >= Self.roundsRange.upperBound,
                    onDecrement: {
                        adjustRounds(by: -1)
                    },
                    onIncrement: {
                        adjustRounds(by: 1)
                    }
                )
            }

            if let validationText {
                Text(validationText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
            }

            Button {
                showsSaveError = !onSave(config)
            } label: {
                Text(saveTitle)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.glassProminent)
            .foregroundStyle(.black)
            .font(.headline.weight(.bold))
            .disabled(!canSave)

            Spacer(minLength: 0)
        }
    }

    private var config: TabataConfig {
        TabataConfig.preset(workSeconds: workSeconds, restSeconds: restSeconds, rounds: rounds)
    }

    private var canSave: Bool {
        existingPresetID != nil || canCreatePreset
    }

    private var validationText: String? {
        if existingPresetID == nil, !canCreatePreset {
            return "Preset limit reached"
        }
        if showsSaveError {
            return "Unable to save preset"
        }
        return nil
    }

    private func adjustWork(by amount: Int) {
        workSeconds = Self.clamped(workSeconds + amount, to: Self.workRange)
        showsSaveError = false
    }

    private func adjustRest(by amount: Int) {
        restSeconds = Self.clamped(restSeconds + amount, to: Self.restRange)
        showsSaveError = false
    }

    private func adjustRounds(by amount: Int) {
        rounds = Self.clamped(rounds + amount, to: Self.roundsRange)
        showsSaveError = false
    }

    private static func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct PresetValueControl: View {
    let title: String
    let value: String
    let decrementDisabled: Bool
    let incrementDisabled: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.semibold))

                Text(value)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.headline.weight(.black))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.glass)
                .foregroundStyle(stepperForeground)
                .disabled(decrementDisabled)
                .accessibilityLabel("Decrease \(title)")

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.black))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.glass)
                .foregroundStyle(stepperForeground)
                .disabled(incrementDisabled)
                .accessibilityLabel("Increase \(title)")
            }
        }
    }

    private var stepperForeground: Color {
        Color(red: 0.05, green: 0.22, blue: 0.28)
    }
}

private extension Color {
    init(_ tabataColor: TabataColor) {
        self.init(red: tabataColor.red, green: tabataColor.green, blue: tabataColor.blue)
    }
}
