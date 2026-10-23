//
//  AppSettingsLink.swift
//  Cue Studio
//

import UIKit

/// Cue's page in the Settings app, for a button that leaves a view model (a toast's "Settings"); views use
/// `OpenURLAction.openAppSettings()`.
enum AppSettingsLink {
    static func open() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
