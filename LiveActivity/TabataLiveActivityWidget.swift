import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TabataLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TabataLiveActivityAttributes.self) { context in
            TabataLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(context.state.tint.opacity(0.86))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.caption.weight(.black))
                        Text(context.state.roundText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    timerText(for: context.state)
                        .font(.title2.monospacedDigit().weight(.black))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: context.state.timerInterval, countsDown: true)
                        .tint(context.state.tint)
                }
            } compactLeading: {
                Text(context.state.symbol)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(context.state.tint)
            } compactTrailing: {
                timerText(for: context.state)
                    .font(.caption2.monospacedDigit().weight(.bold))
            } minimal: {
                Text(context.state.symbol)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(context.state.tint)
            }
            .keylineTint(context.state.tint)
        }
    }

    private func timerText(for state: TabataLiveActivityAttributes.ContentState) -> some View {
        Group {
            if state.isRunning {
                Text(timerInterval: state.timerInterval, countsDown: true)
            } else {
                Text(state.remainingText)
            }
        }
    }
}

private struct TabataLiveActivityLockScreenView: View {
    let state: TabataLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(state.title)
                    .font(.headline.weight(.black))
                Text(state.roundText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
            }

            Spacer()

            if state.isRunning {
                Text(timerInterval: state.timerInterval, countsDown: true)
                    .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
            } else {
                Text(state.remainingText)
                    .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

private extension TabataLiveActivityAttributes.ContentState {
    var tint: Color {
        Color(red: tintRed, green: tintGreen, blue: tintBlue)
    }
}
