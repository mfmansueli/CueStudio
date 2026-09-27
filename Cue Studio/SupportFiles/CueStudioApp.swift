//
//  CueStudioApp.swift
//  Cue Studio
//

import AppIntents
import SwiftUI

@main
struct CueStudioApp: App {
    /// The app session's services. Created here, before any scene, because Siri and Shortcuts can
    /// ask for scripts (App Intents) without the UI ever appearing.
    @State private var services: AppServices

    init() {
        CueStudioFont.registerFonts()
        let services = AppServices(options: LaunchOptions.fromProcess())
        services.load()
        services.registerIntentDependencies()
        _services = State(initialValue: services)
    }

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
        }
    }
}
