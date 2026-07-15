//
//  KeepAliveLiveActivityWidget.swift
//  StikDebugWidgets
//
//  Live Activity presentation for the background keep-alive session. Shows the
//  held app in the Dynamic Island (compact, expanded, and minimal) and on the
//  Lock Screen.
//

import WidgetKit
import SwiftUI
import ActivityKit

@available(iOS 16.1, *)
struct KeepAliveLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KeepAliveActivityAttributes.self) { context in
            // Lock Screen / banner presentation.
            KeepAliveLockScreenView(appName: context.state.appName)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.green)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("JIT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.appName)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Held alive in the background")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "bolt.circle.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(context.state.appName)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: "bolt.circle.fill")
                    .foregroundStyle(.green)
            }
            .keylineTint(.green)
        }
    }
}

@available(iOS 16.1, *)
private struct KeepAliveLockScreenView: View {
    let appName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.circle.fill")
                .font(.title)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Keeping \(appName) alive")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Held in the background")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
    }
}
