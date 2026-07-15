//
//  StikDebugWidgetsBundle.swift
//  StikDebugWidgets
//
//  Widget extension bundle. Hosts the keep-alive Live Activity so it can be
//  rendered in the Dynamic Island and on the Lock Screen.
//

import WidgetKit
import SwiftUI

@main
struct StikDebugWidgetsBundle: WidgetBundle {
    var body: some Widget {
        KeepAliveLiveActivityWidget()
    }
}
