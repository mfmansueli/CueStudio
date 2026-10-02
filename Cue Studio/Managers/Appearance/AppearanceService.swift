//
//  AppearanceService.swift
//  Cue Studio
//

import Foundation

/// The creator's choice of light, dark or the iPhone's own appearance for Cue's screens. It is
/// kept on this iPhone and read by `RootView`.
@MainActor
@Observable
final class AppearanceService {
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: DefaultsKey.appAppearance) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: DefaultsKey.appAppearance).flatMap(AppAppearance.init(rawValue:)) ?? .system
    }
}
