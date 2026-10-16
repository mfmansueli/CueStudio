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
    /// "Media" on the main toolbar: a photo or video on top of the video or as a clip, chosen in the sheet.
    case addMediaChoice
    /// Cover Studio, over the editor.
    case openCoverStudio
    // Clip
    case splitClip
    case duplicateClip
    case copyLook
    case pasteLook
    case deleteClip
    // Text
    case addText(TextOverlayRole)
    /// The comment this script answers, as a card over the first seconds.
    case addCommentCard
    case styleAllTexts
    case editText
    case toggleKeyframe
    case duplicateText
    case deleteText
    // Captions menu
    case writeCaptionsByHand
    case deleteAllCaptions
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
    case replaceMedia
    case deleteMedia
}
