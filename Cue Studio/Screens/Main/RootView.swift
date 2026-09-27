//
//  RootView.swift
//  Cue Studio
//

import SwiftUI

/// Owns the app session's services and injects them. Cue has no account or onboarding gate:
/// a first run simply shows the empty library.
struct RootView: View {
    @State private var services: AppServices
    @Environment(\.scenePhase) private var scenePhase

    init(options: LaunchOptions) {
        let services = AppServices(options: options)
        services.load()
        _services = State(initialValue: services)
    }

    var body: some View {
        MainView(services: services)
            // Inside the environment: the host reads ToastService from it.
            .toastHost()
            .environment(services)
            .task {
                await services.store.start()
            }
            .task {
                await services.rules.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                services.quota.refreshMonth()
                Task { await services.store.refreshEntitlements() }
            }
    }
}
