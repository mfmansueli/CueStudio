//
//  OpenURLAction+AppSettings.swift
//  Cue Studio
//

import SwiftUI

extension OpenURLAction {
    /// Opens Cue's page in the Settings app, where a permission said no or the app's language is changed.
    @MainActor
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { self(url) }
    }
}
