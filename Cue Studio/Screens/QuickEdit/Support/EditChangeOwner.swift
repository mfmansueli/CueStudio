//
//  EditChangeOwner.swift
//  Cue Studio
//

import Foundation

/// Who started a change that is still going (`EditDocument.beginChange(by:)`): only it ends it, and a panel's ends when the
/// panel goes away too.
enum EditChangeOwner: Hashable {
    /// A control that lives in the open panel: a slider, a strip, a handle drawn on the preview only while the panel is open.
    case panel
    /// A finger on the timeline or the preview, or a sheet.
    case gesture
}
