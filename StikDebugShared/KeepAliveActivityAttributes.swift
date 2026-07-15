//
//  KeepAliveActivityAttributes.swift
//  StikDebug
//
//  Shared between the app (which starts/updates/ends the activity) and the
//  widget extension (which renders it in the Dynamic Island / on the Lock
//  Screen). Keep this file in the StikDebugShared group so both targets compile
//  the same type.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct KeepAliveActivityAttributes: ActivityAttributes {
    /// The parts of the activity that change while it is live.
    struct ContentState: Codable, Hashable {
        /// The display name of the app currently being held alive.
        var appName: String
    }

    /// The app being held alive when the activity started.
    var appName: String
    /// The bundle identifier of that app.
    var bundleID: String
}
#endif
