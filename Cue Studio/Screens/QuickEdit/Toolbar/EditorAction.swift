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
    /// Replace clip: another video from Photos in the clip's place, keeping its length and effects.
    case replaceClip
    /// Extract audio: the picked clip's (or video's) sound on a track of its own, the clip muted.
    case extractAudio
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
    /// Locks the picked text, photo or video, music or voice-over in place on the timeline, or unlocks it.
    case toggleLock
    case deleteText
    // Captions menu
    /// A new line at the playhead, in the Captions panel.
    case addCaptionLine
    case writeCaptionsByHand
    /// Edit by text: cut words out of the video.
    case editByText
    case deleteAllCaptions
    /// Find and replace in every line.
    case findInCaptions
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
    /// Split a photo or video in two at the playhead.
    case splitMedia
    /// A support moved back to meet the one before it.
    case closeGap
    /// The photo or video kept in the creator's library, to reuse in other videos.
    case saveMediaToLibrary
    /// Mask: only part of the picked photo or video shows (a split screen's support says why it can't).
    case openMask
    /// The split screen's panel on one of its tabs (Layout, Framing, Sound, Part), for the picked support.
    case openSplitTab(EditorPanelTab)
    /// The split screen's two contents trade places.
    case swapSplit
    /// The picked photo's or video's ready-made motion, Track and keyframes.
    case openMediaMotion
    /// The picked caption line's words, to emphasize some (Captions, the line's More open).
    case emphasizeCaption
    // Blur area
    /// A face, a plate or a name hidden: the faces in the frame to tap, or an area to draw.
    case addBlurArea
    /// The picked area follows its subject.
    case followBlur
    /// The picked area's stretch plays, to check it.
    case reviewBlur
    case deleteBlur
}
