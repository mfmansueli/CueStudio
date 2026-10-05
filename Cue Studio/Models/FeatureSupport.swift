//
//  FeatureSupport.swift
//  Cue Studio
//

import Foundation

/// What a device can do for a language and feature, as the system's own frameworks answer it: it works,
/// it works once a model is on the device, or it doesn't work here (and why).
nonisolated enum FeatureSupport: Hashable, Sendable {
    /// Works now.
    case supported
    /// Supported, but the model has to be downloaded or finish preparing first. Never counted as a
    /// failure: using the feature asks for the model.
    case notInstalled
    /// Doesn't work on this device for this language.
    case unavailable(Cause)

    /// Why a feature isn't available. Each is a different thing for the creator to do (or not).
    enum Cause: Hashable, Sendable {
        /// The feature runs here, but not in this language.
        case languageNotSupported
        /// This device (or this system version) can't run the feature at all.
        case deviceNotSupported
        /// Turned off in Settings (Apple Intelligence).
        case turnedOff
        /// Cue's interface has no translation of its own for this variant; it reads in the language it falls back to.
        case variantNotTranslated
    }

    /// Worth offering: it works, or it will once the model is on the device.
    var isUsable: Bool {
        if case .unavailable = self { false } else { true }
    }

    var isSupported: Bool { self == .supported }
}
