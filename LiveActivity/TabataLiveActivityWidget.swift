import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TabataLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TabataLiveActivityAttributes.self) { context in
            TabataLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(context.state.tint.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(context.state.tint)
                            .frame(width: 7, height: 7)

                        Text(context.state.title)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.roundText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 7) {
                        TabataLiveActivityTimerText(state: context.state)
                            .font(.system(size: 40, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .center)

                        TabataLiveActivityProgressBar(state: context.state, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Text(context.state.symbol)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(context.state.tint)
            } compactTrailing: {
                TabataLiveActivityTimerText(state: context.state)
                    .font(.caption2.monospacedDigit().weight(.bold))
            } minimal: {
                Text(context.state.symbol)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(context.state.tint)
            }
            .keylineTint(context.state.tint)
            .contentMargins(.horizontal, 16, for: .expanded)
            .contentMargins(.vertical, 8, for: .expanded)
        }
    }
}

private struct TabataLiveActivityLockScreenView: View {
    let state: TabataLiveActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)

                        Text(state.title)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Text(state.isRunning ? "ACTIVE" : "PAUSED")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.68))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TabataLiveActivityTimerText(state: state)
                    .font(.system(size: 46, weight: .black, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(minWidth: 112, alignment: .center)

                Text(state.roundText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            TabataLiveActivityProgressBar(state: state, height: 6)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}

private struct TabataLiveActivityTimerText: View {
    let state: TabataLiveActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isRunning {
                Text(timerInterval: state.timerInterval, countsDown: true)
            } else {
                Text(state.remainingText)
            }
        }
    }
}

private struct TabataLiveActivityProgressBar: View {
    let state: TabataLiveActivityAttributes.ContentState
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.22))

            if state.isRunning {
                ProgressView(timerInterval: state.timerInterval, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(.white)
            } else {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.white)
                        .frame(width: proxy.size.width * state.elapsedFraction)
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

private extension TabataLiveActivityAttributes.ContentState {
    var tint: Color {
        Color(red: tintRed, green: tintGreen, blue: tintBlue)
    }
}
