//
//  KeepAliveLiveActivity.swift
//  StikDebug
//
//  App-side controller for the background keep-alive Live Activity. Starts a
//  Live Activity when a hold begins so it shows in the Dynamic Island (on
//  compatible iPhones) and on the Lock Screen, and ends it when the hold stops.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

enum KeepAliveLiveActivity {
    private static let lock = NSLock()
    /// Type-erased storage for the current `Activity`, so this enum has no
    /// availability requirement of its own and callers don't need to guard.
    private static var storage: Any?

    /// Start (or replace) the keep-alive Live Activity for the given app.
    static func start(appName: String, bundleID: String) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        startActivity(appName: appName, bundleID: bundleID)
        #endif
    }

    /// Update the app name shown by the current Live Activity, if any.
    static func update(appName: String) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        updateActivity(appName: appName)
        #endif
    }

    /// End the current keep-alive Live Activity, if any.
    static func end() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        endActivity()
        #endif
    }

    /// End any keep-alive activities left running by a previous launch (for
    /// example if the app was force-quit or crashed mid-hold). Call this once at
    /// startup, when no hold is active.
    static func endStaleActivities() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        for activity in Activity<KeepAliveActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        lock.lock()
        storage = nil
        lock.unlock()
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private static func startActivity(appName: String, bundleID: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            LogManager.shared.addInfoLog("Keep-alive Live Activity not started: Live Activities are disabled in Settings")
            return
        }

        // Only one hold runs at a time, so make sure any stale activity is gone.
        endActivity()

        let attributes = KeepAliveActivityAttributes(appName: appName, bundleID: bundleID)
        let state = KeepAliveActivityAttributes.ContentState(appName: appName)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
            lock.lock()
            storage = activity
            lock.unlock()
        } catch {
            LogManager.shared.addErrorLog("Keep-alive Live Activity failed to start: \(error.localizedDescription)")
        }
    }

    @available(iOS 16.1, *)
    private static func updateActivity(appName: String) {
        lock.lock()
        let activity = storage as? Activity<KeepAliveActivityAttributes>
        lock.unlock()
        guard let activity else { return }

        let state = KeepAliveActivityAttributes.ContentState(appName: appName)
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    @available(iOS 16.1, *)
    private static func endActivity() {
        lock.lock()
        let activity = storage as? Activity<KeepAliveActivityAttributes>
        storage = nil
        lock.unlock()
        guard let activity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    #endif
}
