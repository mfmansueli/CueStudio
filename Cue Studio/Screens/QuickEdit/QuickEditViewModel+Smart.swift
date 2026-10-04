//
//  QuickEditViewModel+Smart.swift
//  Cue Studio
//

import Foundation

/// What the ✦ Smart panel says under each tile: what is already on.
extension QuickEditViewModel {
    /// "12 lines" once the take has captions; nil before.
    var smartCaptionsStatus: String? {
        edit.captions.isEmpty ? nil : String(localized: "\(edit.captions.count) lines")
    }

    /// "Soft" or "Strong" when Studio Voice does something; nil when it is off.
    var smartVoiceStatus: String? {
        edit.voiceEnhancement == .off ? nil : edit.voiceEnhancement.label
    }

    /// "On" once the picture was measured and corrected; nil before.
    var smartAdjustStatus: String? {
        edit.autoCorrection == nil ? nil : String(localized: "On")
    }
}
