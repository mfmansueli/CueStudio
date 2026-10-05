//
//  CueStudioApp.swift
//  Cue Studio
//

import AppIntents
import SwiftUI
import TipKit

@main
struct CueStudioApp: App {
    /// The app session's services. Created here, before any scene, because Siri and Shortcuts can
    /// ask for scripts (App Intents) without the UI ever appearing.
    @State private var services: AppServices

    init() {
        TelemetryManager.start()
        CueStudioFont.registerFonts()
        let services = AppServices(options: LaunchOptions.fromProcess())
        services.load()
        services.registerIntentDependencies()
        Self.configureTips(inMemory: LaunchOptions.fromProcess().isInMemory)
        _services = State(initialValue: services)
    }

    /// TipKit shows the My Cue Voice tip; the scheduler decides when (frequency is its own: one a day, three a week). UI tests start
    /// with an empty tip store, so an invalidated tip never carries over between runs.
    private static func configureTips(inMemory: Bool) {
        if inMemory { try? Tips.resetDatastore() }
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
        }
    }
}
