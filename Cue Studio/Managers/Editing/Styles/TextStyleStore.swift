//
//  TextStyleStore.swift
//  Cue Studio
//

import Foundation

/// "My style" in UserDefaults, on this device.
@MainActor
final class TextStyleStore: TextStyleStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var myStyle: TextLook? {
        get {
            defaults.data(forKey: DefaultsKey.myTextStyle).flatMap { try? JSONDecoder().decode(TextLook.self, from: $0) }
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: DefaultsKey.myTextStyle)
            } else {
                defaults.removeObject(forKey: DefaultsKey.myTextStyle)
            }
        }
    }
}
