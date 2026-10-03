//
//  ScriptActions.swift
//  Cue Studio
//

import Foundation

/// What can be done to a script from a menu. Built once by the screen and shared by the context
/// menu, the "More" dialog and the detail toolbar.
struct ScriptActions {
    var record: (Script) -> Void
    var studio: (Script) -> Void
    var edit: (Script) -> Void
    var duplicate: (Script) -> Void
    var move: (Script, String?) -> Void
    var moveToNewFolder: (Script) -> Void
    var delete: (Script) -> Void
    /// "Make a version for…" another platform; nil hides it (the library menus).
    var makeVersion: ((Script, Platform) -> Void)? = nil
    /// Which language the script is in (nil is Auto-detect). Never translates the text.
    var setLanguage: ((Script, CueLanguage?) -> Void)? = nil
}
