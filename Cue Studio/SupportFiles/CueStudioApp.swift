//
//  CueStudioApp.swift
//  Cue Studio
//

import SwiftUI

@main
struct CueStudioApp: App {
    private let launchOptions: LaunchOptions

    init() {
        CueStudioFont.registerFonts()
        launchOptions = LaunchOptions.fromProcess()
    }

    var body: some Scene {
        WindowGroup {
            RootView(options: launchOptions)
        }
    }
}
