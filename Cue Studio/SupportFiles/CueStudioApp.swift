//
//  CueStudioApp.swift
//  Cue Studio
//

import AppIntents
import SwiftUI
import TipKit
import UIKit

@main
struct CueStudioApp: App {
    /// The app session's services. Created here, before any scene, because Siri and Shortcuts can
    /// ask for scripts (App Intents) without the UI ever appearing. None while the app only hosts the unit tests.
    @State private var services: AppServices?
    /// UI tests: nothing animates (`-uiTestFastAnimations`).
    private var animationsOff = false

    init() {
        TelemetryManager.start()
        CueStudioFont.registerFonts()
        // Hosting the unit tests: an empty window (some tests put a view in it), nothing loaded, nothing drawing.
        guard !TestHost.isHostingUnitTests else { return }
        let options = LaunchOptions.fromProcess()
        let services = AppServices(options: options)
        services.load()
        services.registerIntentDependencies()
        Self.configureTips(inMemory: options.isInMemory)
        _services = State(initialValue: services)
        if options.animationsOff {
            // Sheets, pushes and alerts appear at once; SwiftUI's own animations are off at the root (`body`).
            UIView.setAnimationsEnabled(false)
            animationsOff = true
        }
    }

    /// TipKit shows the My Cue Voice tip; the scheduler decides when (frequency is its own: one a day, three a week). UI tests start
    /// with an empty tip store, so an invalidated tip never carries over between runs.
    private static func configureTips(inMemory: Bool) {
        if inMemory { try? Tips.resetDatastore() }
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        WindowGroup {
            if let services {
                RootView(services: services)
                    .transaction { transaction in
                        guard animationsOff else { return }
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
            }
        }
    }
}
