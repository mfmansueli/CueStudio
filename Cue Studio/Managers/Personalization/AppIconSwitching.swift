//
//  AppIconSwitching.swift
//  Cue Studio
//

import UIKit

/// Switches the app's Home Screen icon.
@MainActor
protocol AppIconSwitching: AnyObject {
    var current: AppIconChoice { get }
    func set(_ icon: AppIconChoice) async throws
}
