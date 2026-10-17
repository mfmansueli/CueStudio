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
    /// Freeze frame: the frame under the playhead held as a clip of its own.
    case freezeFrame
    /// Reverse: the clip plays backwards (or forward again).
    case reverseClip
    /// Reorder: the clips in a list to drag (also holding a clip on the timeline).
    case reorderClips
    case copyLook
    case pasteLook
    case deleteClip
    // Text
    case addText(TextOverlayRole)
    /// An arrow, a circle or a tag over the video (Cover Studio's graphics, timed like a text).
    case addGraphic(CoverItemKind)
    /// The comment this script answers, as a card over the first seconds.
    case addCommentCard
    case styleAllTexts
    case editText
    case toggleKeyframe
    /// Track: the picked text, graphic or photo follows what's under it in the video.
    case trackItem
    case duplicateText
    /// The picked text's Style › Motion, where its ready animations are.
    case openTextAnimation
    case deleteText
    // Captions menu
    case writeCaptionsByHand
    /// Edit by text: cut words out of the video.
    case editByText
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
    case duplicateMedia
    case deleteMedia
}
