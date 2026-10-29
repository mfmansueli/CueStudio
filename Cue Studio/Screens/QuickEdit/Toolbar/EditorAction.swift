//
//  EditorAction.swift
//  Cue Studio
//

import Foundation

/// What a toolbar button does. The toolbar lists actions for the current context
/// (`QuickEditViewModel.toolbarItems`) and the view model performs them (`perform(_:)`, checking again at the tap that each can
/// work and saying why when it can't), so the contexts are tested without the screen.
enum EditorAction: Hashable {
    // Main toolbar
    case selectClipAtPlayhead
    case openMenu(EditorToolMenu)
    case openCaptions
    case open(EditorPanel)
    /// Adjust, Skin, Filters or Background at the reach the button says: the whole video (the main bar, and the badged shortcut
    /// on an item's bar) or the picked clip's own (its bar).
    case openLook(EditorLookTool, wholeVideo: Bool)
    /// ✦ Smart on one of its tabs: Tools (✦ Smart), Templates, Brand kit.
    case openSmart(SmartPanelSection)
    case addMedia
    /// A photo or video on top of the video or as a clip, the way chosen in the sheet (on the way it was last added).
    case addMediaChoice
    /// The Media bar: the gallery opened on one way of adding (the sheet's cards stay to change it).
    case addMediaAs(MediaInsertMode)
    /// The Media bar's Your library: the sheet opened on what the creator kept to reuse (a logo goes straight on).
    case addMediaFromLibrary
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
    /// The picked clip's Mute: its sound off, or on again (Volume's "Mute this clip").
    case toggleClipMute
    /// The picked clip's Transition: the cut after it (the last clip's, the one before it), its Transition panel open.
    case openClipTransition
    /// The picked clip's Mirror: its picture flipped left to right, or back.
    case toggleClipMirror
    /// Reset clip: the picked clip back as filmed (`ClipsViewModel.resetClip`).
    case resetClip
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
    /// The Captions bar's Show: every line shown or hidden (the Captions panel's switch).
    case toggleCaptionsShown
    /// The Captions bar's Translate: the Captions panel with the translation sheet over it.
    case openCaptionTranslation
    // Caption
    case editCaption
    case splitCaption
    case joinCaption
    case deleteCaption
    // Audio
    case openMusic
    /// The Audio bar's Sound effects: Cue's sound effects alone, to add at the playhead.
    case openSoundEffects
    case replaceMusic
    case deleteMusic
    /// Text to speech: a new voice-over said from text.
    case openTextToSpeech
    /// Edit text on a spoken voice-over: says it again in place.
    case editSpokenText
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
    /// An area drawn in the middle of the frame, to drag onto a plate, a name or anything else (the Blur area bar).
    case drawBlurArea
    /// The Blur area bar's Compare: the preview without any Blur area, or with them again.
    case compareBlur
    /// The picked area follows its subject.
    case followBlur
    /// The picked area's stretch plays, to check it.
    case reviewBlur
    case deleteBlur
}
