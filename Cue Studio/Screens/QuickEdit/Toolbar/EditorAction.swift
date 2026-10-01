//
//  EditorAction.swift
//  Cue Studio
//

import Foundation

/// What a toolbar button does. The toolbar lists actions for the current context
/// (`QuickEditViewModel.toolbarItems`) and the view model performs them (`perform(_:)`), so the
/// contexts are tested without the screen.
enum EditorAction: Hashable {
    // Main toolbar
    case selectClipAtPlayhead
    case openMenu(EditorToolMenu)
    case openCaptions
    case open(EditorPanel)
    case addMedia
    // Clip
    case splitClip
    case duplicateClip
    case deleteClip
    // Text
    case addText(TextOverlayRole)
    case styleAllTexts
    case editText
    case toggleKeyframe
    case duplicateText
    case deleteText
    // Caption
    case editCaption
    case splitCaption
    case joinCaption
    case deleteCaption
    // Audio
    case openMusic
    case replaceMusic
    case deleteMusic
    case reRecordVoiceOver
    case deleteVoiceOver
    // Media
    case deleteMedia
}
