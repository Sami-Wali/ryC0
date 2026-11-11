import ActivityKit
import SwiftUI
import WidgetKit

@main
struct GuestActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GuestActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(link(to: context.attributes))
        } dynamicIsland: { context in
            let progress = context.isStale ? nil : context.state.progress
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    activityIcon(size: 17)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if let progress {
                            percentage(progress).font(.title3.weight(.bold))
                        } else {
                            Text(context.attributes.appName).font(.caption.weight(.semibold))
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.title).font(.headline).lineLimit(1)
                        progressBar(progress)
                        detail(context.state.detail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                activityIcon(size: 14)
            } compactTrailing: {
                compactStatus(progress)
            } minimal: {
                compactStatus(progress)
            }
            .widgetURL(link(to: context.attributes))
        }
    }

    private func lockScreen(_ context: ActivityViewContext<GuestActivityAttributes>) -> some View {
        let progress = context.isStale ? nil : context.state.progress
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                activityIcon(size: 17)
                    .frame(width: 34, height: 34)
                    .background(.cyan.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.appName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(context.state.title).font(.headline).lineLimit(1)
                }
                Spacer(minLength: 4)
                if let progress {
                    percentage(progress).font(.subheadline.weight(.bold))
                }
            }
            progressBar(progress)
            detail(context.state.detail)
        }
        .padding(14)
    }

    private func activityIcon(size: CGFloat) -> some View {
        Image(systemName: "waveform")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.cyan)
            .accessibilityHidden(true)
    }

    private func percentage(_ progress: Double) -> some View {
        Text(progress, format: .percent.precision(.fractionLength(0)))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(.cyan)
    }

    @ViewBuilder
    private func detail(_ text: String) -> some View {
        if !text.isEmpty {
            Text(text).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    @ViewBuilder
    private func progressBar(_ progress: Double?) -> some View {
        if let progress {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.cyan)
        }
    }

    @ViewBuilder
    private func compactStatus(_ progress: Double?) -> some View {
        if let progress {
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(.cyan)
        } else {
            activityIcon(size: 12)
        }
    }

    private func link(to attributes: GuestActivityAttributes) -> URL? {
        var components = URLComponents()
        components.scheme = attributes.hostScheme
        components.host = "livecontainer-launch"
        components.queryItems = [URLQueryItem(name: "bundle-name", value: attributes.bundlePath)]
        return components.url
    }
}
