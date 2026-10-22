//
//  CueWatchApp.swift
//  Cue Studio Watch
//

import SwiftUI

/// Cue on the wrist (v31): records, ends and drives the text of the take on the iPhone. The watch only asks; every screen is
/// the iPhone's answer.
@main
struct CueWatchApp: App {
    @State private var session = WatchSessionModel()
    @Environment(\.scenePhase) private var scenePhase

    private func start() {
        #if DEBUG
        if let demo = WatchDemo.requested {
            session.show(demo.snapshot)
            return
        }
        #endif
        session.start()
    }

    private var isDemo: Bool {
        #if DEBUG
        WatchDemo.requested != nil
        #else
        false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(session: session)
                .task { start() }
                // Raising the wrist asks again: never an old state as if it were now.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, !isDemo { session.refresh() }
                }
        }
    }
}
