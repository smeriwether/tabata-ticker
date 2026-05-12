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
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(context.state.title)
                                .font(.caption.weight(.black))
                                .foregroundStyle(context.state.tint)
                                .lineLimit(1)

                            Text(context.state.roundText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            Spacer(minLength: 8)
                        }

                        timerText(for: context.state)
                            .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .center)

                        ProgressView(timerInterval: context.state.timerInterval, countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                        .tint(context.state.tint)
                    }
                    .padding(.top, 12)
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
            .contentMargins(.horizontal, 18, for: .expanded)
            .contentMargins(.vertical, 10, for: .expanded)
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
