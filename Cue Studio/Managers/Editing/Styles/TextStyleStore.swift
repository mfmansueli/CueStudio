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

    /// The cover look a creator saved in the v26 Cover panel, what Cover Studio's style starts from when there's none.
    private var myCoverLook: CoverLook? {
        defaults.data(forKey: DefaultsKey.myCoverStyle).flatMap { try? JSONDecoder().decode(CoverLook.self, from: $0) }
    }

    /// Cover Studio's style; a creator who saved one in the v26 Cover panel starts from it, converted.
    var myCoverStyle: CoverStyle? {
        get {
            if let data = defaults.data(forKey: DefaultsKey.myCoverStudioStyle), let style = try? JSONDecoder().decode(CoverStyle.self, from: data) {
                return style
            }
            guard let look = myCoverLook else { return nil }
            var design = CoverDesign()
            design.apply(look)
            var cover = VideoCover(source: .frame(0))
            cover.design = design
            return CoverComposition(legacy: cover).style
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: DefaultsKey.myCoverStudioStyle)
            } else {
                defaults.removeObject(forKey: DefaultsKey.myCoverStudioStyle)
            }
        }
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

    var myCaptionStyle: MyCaptionStyle? {
        get {
            defaults.data(forKey: DefaultsKey.myCaptionStyle).flatMap { try? JSONDecoder().decode(MyCaptionStyle.self, from: $0) }
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: DefaultsKey.myCaptionStyle)
            } else {
                defaults.removeObject(forKey: DefaultsKey.myCaptionStyle)
            }
        }
    }
}
