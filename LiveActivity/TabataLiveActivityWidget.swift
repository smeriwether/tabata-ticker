import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TabataLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TabataLiveActivityAttributes.self) { context in
            TabataLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(.black.opacity(0.88))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    TabataLiveActivityExpandedView(state: context.state)
                }
            } compactLeading: {
                TabataLiveActivityPhaseIcon(state: context.state, size: 17, iconSize: 9)
            } compactTrailing: {
                TabataLiveActivityTimerText(state: context.state)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 42)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
            } minimal: {
                TabataLiveActivityPhaseIcon(state: context.state, size: 14, iconSize: 8)
            }
            .keylineTint(context.state.tint)
            .contentMargins(.horizontal, 24, for: .expanded)
            .contentMargins(.vertical, 11, for: .expanded)
        }
    }
}

// The countdown and the progress bar are the system's own timer views: they redraw every second
// inside the widget process, while everything else here only changes when the app sends an update.
private struct TabataLiveActivityTimerText: View {
    let state: TabataLiveActivityAttributes.ContentState

    var body: some View {
        Text(
            timerInterval: state.timerRange,
            pauseTime: state.pausedAt,
            countsDown: true,
            showsHours: false
        )
        .monospacedDigit()
    }
}

private struct TabataLiveActivityLockScreenView: View {
    let state: TabataLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 10) {
                TabataLiveActivityPhaseLabel(state: state, dotSize: 7)

                Spacer(minLength: 10)

                Text("Round \(state.roundText)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.10), in: Capsule())
            }

            HStack(alignment: .lastTextBaseline, spacing: 12) {
                TabataLiveActivityTimerText(state: state)
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 12)

                Text(state.statusText)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(state.tint)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(state.tint.opacity(0.16), in: Capsule())
            }

            TabataLiveActivityProgressBar(state: state, height: 6)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
    }
}

private struct TabataLiveActivityExpandedView: View {
    let state: TabataLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                TabataLiveActivityPhaseLabel(state: state, dotSize: 6)

                Spacer(minLength: 10)

                Text(state.roundText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.10), in: Capsule())
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                TabataLiveActivityTimerText(state: state)
                    .font(.system(size: 43, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer(minLength: 8)

                Text(state.statusText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(state.tint)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(state.tint.opacity(0.16), in: Capsule())
            }

            TabataLiveActivityProgressBar(state: state, height: 5)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TabataLiveActivityPhaseLabel: View {
    let state: TabataLiveActivityAttributes.ContentState
    let dotSize: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            TabataLiveActivityPhaseIcon(state: state, size: dotSize + 11, iconSize: max(8, dotSize))

            Text(state.title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
    }
}

private struct TabataLiveActivityPhaseIcon: View {
    let state: TabataLiveActivityAttributes.ContentState
    let size: CGFloat
    let iconSize: CGFloat

    var body: some View {
        Image(systemName: state.phaseIconName)
            .font(.system(size: iconSize, weight: .black))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(state.tint, in: Circle())
    }
}

private struct TabataLiveActivityProgressBar: View {
    let state: TabataLiveActivityAttributes.ContentState
    let height: CGFloat

    var body: some View {
        if state.isRunning {
            ProgressView(timerInterval: state.timerRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(state.tint)
        } else {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.22))

                GeometryReader { proxy in
                    Capsule()
                        .fill(state.tint)
                        .frame(width: proxy.size.width * state.pausedFraction)
                }
            }
            .frame(height: height)
            .clipShape(Capsule())
        }
    }
}

private extension TabataLiveActivityAttributes.ContentState {
    var tint: Color {
        Color(red: tintRed, green: tintGreen, blue: tintBlue)
    }
}
