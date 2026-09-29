//
//  RootView.swift
//  Cue Studio
//

import AppIntents
import SwiftUI

/// Injects the app session's services and takes requests from Siri and Shortcuts. Cue has no
/// onboarding gate: a first run simply shows the empty library.
struct RootView: View {
    let services: AppServices

    @Environment(\.scenePhase) private var scenePhase

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
            .task {
                await services.session.verify()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await services.store.refreshEntitlements() }
            }
            .onChange(of: IntentRouter.shared.pending, initial: true) {
                handleIntent()
            }
            // A remote pairing code scanned with the Camera on this device.
            .onOpenURL { url in
                guard let code = RemotePairing.code(from: url), services.remote.join(code: code) else { return }
                services.presentation.openRemoteController()
            }
            .onChange(of: services.library.scripts.count, initial: true) {
                // Keeps "Record {script}" phrases in step with the library.
                CueShortcuts.updateAppShortcutParameters()
            }
    }

    private func handleIntent() {
        guard let route = IntentRouter.shared.take() else { return }
        switch route {
        case .record(let id):
            guard services.library.script(id: id) != nil else { return }
            services.presentation.openPrompter(scriptID: id, mode: .selfie)
        case .newScript:
            services.presentation.closePrompter()
            services.presentation.present(.newScript)
        }
    }
}
