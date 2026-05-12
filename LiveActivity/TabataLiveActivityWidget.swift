import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TabataLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TabataLiveActivityAttributes.self) { context in
            TabataLiveActivityTimelineView(state: context.state) { display in
                TabataLiveActivityLockScreenView(display: display)
            }
            .activityBackgroundTint(.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    TabataLiveActivityTimelineView(state: context.state) { display in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 10) {
                                TabataLiveActivityPhaseLabel(display: display, dotSize: 6)

                                Spacer(minLength: 10)

                                Text(display.roundText)
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .lineLimit(1)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.10), in: Capsule())
                            }

                            HStack(alignment: .lastTextBaseline, spacing: 10) {
                                TabataLiveActivityTimerText(display: display)
                                    .font(.system(size: 43, weight: .black, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)

                                Spacer(minLength: 8)

                                Text(display.statusText)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(display.tint)
                                    .textCase(.uppercase)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(display.tint.opacity(0.16), in: Capsule())
                            }

                            TabataLiveActivityProgressBar(display: display, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } compactLeading: {
                TabataLiveActivityTimelineView(state: context.state) { display in
                    TabataLiveActivityPhaseIcon(display: display, size: 17, iconSize: 9)
                }
            } compactTrailing: {
                TabataLiveActivityTimelineView(state: context.state) { display in
                    TabataLiveActivityTimerText(display: display)
                        .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            } minimal: {
                TabataLiveActivityTimelineView(state: context.state) { display in
                    TabataLiveActivityPhaseIcon(display: display, size: 14, iconSize: 8)
                }
            }
            .keylineTint(context.state.tint)
            .contentMargins(.horizontal, 24, for: .expanded)
            .contentMargins(.vertical, 11, for: .expanded)
        }
    }
}

private struct TabataLiveActivityTimelineView<Content: View>: View {
    let state: TabataLiveActivityAttributes.ContentState
    let content: (TabataLiveActivityDisplayState) -> Content

    var body: some View {
        TimelineView(.periodic(from: state.startsAt, by: 1)) { context in
            content(state.displayState(at: context.date))
        }
    }
}

private struct TabataLiveActivityLockScreenView: View {
    let display: TabataLiveActivityDisplayState

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 10) {
                TabataLiveActivityPhaseLabel(display: display, dotSize: 7)

                Spacer(minLength: 10)

                Text("Round \(display.roundText)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.10), in: Capsule())
            }

            HStack(alignment: .lastTextBaseline, spacing: 12) {
                TabataLiveActivityTimerText(display: display)
                    .font(.system(size: 50, weight: .black, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 12)

                Text(display.statusText)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(display.tint)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(display.tint.opacity(0.16), in: Capsule())
            }

            TabataLiveActivityProgressBar(display: display, height: 6)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
    }
}

private struct TabataLiveActivityPhaseLabel: View {
    let display: TabataLiveActivityDisplayState
    let dotSize: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            TabataLiveActivityPhaseIcon(display: display, size: dotSize + 11, iconSize: max(8, dotSize))

            Text(display.title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
    }
}

private struct TabataLiveActivityPhaseIcon: View {
    let display: TabataLiveActivityDisplayState
    let size: CGFloat
    let iconSize: CGFloat

    var body: some View {
        Image(systemName: display.phaseIconName)
            .font(.system(size: iconSize, weight: .black))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(display.tint, in: Circle())
    }
}

private struct TabataLiveActivityTimerText: View {
    let display: TabataLiveActivityDisplayState

    var body: some View {
        Text(display.remainingText)
    }
}

private struct TabataLiveActivityProgressBar: View {
    let display: TabataLiveActivityDisplayState
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.22))

            GeometryReader { proxy in
                Capsule()
                    .fill(display.tint)
                    .frame(width: proxy.size.width * display.elapsedFraction)
                    .shadow(color: display.tint.opacity(0.55), radius: 4)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

private extension TabataLiveActivityDisplayState {
    var tint: Color {
        Color(red: tintRed, green: tintGreen, blue: tintBlue)
    }
}

private extension TabataLiveActivityAttributes.ContentState {
    var tint: Color {
        Color(red: tintRed, green: tintGreen, blue: tintBlue)
    }
}
