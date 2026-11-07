//
//  BrandViewModel.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// The creator's own things in the editor (`EditorPart`): the media library (in Add photo or video), brand kits (Templates ›
/// Brand), imported fonts and the script libraries' downloaded ones (in every font picker).
/// The library, the kits and the fonts live in their stores, outside any
/// video; what this part puts on a video becomes the video's own (its link to a file, a copy of a style), one undo step each.
///
/// Each part of the work is in its own extension (`+Library`, `+Kits`, `+Fonts`, `+FontPacks`).
@MainActor
@Observable
final class BrandViewModel: EditorPart {
    let session: EditorSession
    @ObservationIgnored let library: MediaLibraryStore
    @ObservationIgnored let kits: BrandKitStore
    @ObservationIgnored let fonts: CustomFontStore
    /// The script libraries' files (`FontPackStore`).
    let fontPacks: FontPackStore
    @ObservationIgnored let styles: TextStyleStoring
    /// The creator's script language and the app's, for the libraries a picker offers (`ScriptLibraryOffer`).
    @ObservationIgnored let writingLanguages: () -> (script: CueLanguage?, interface: CueLanguage?)

    /// Add photo or video shows the creator's library instead of Photos (kept while the editor is open).
    var showsLibrary = false
    /// The library's filter and search in Add photo or video.
    var libraryFilter: LibraryFilter = .all
    var librarySearch = ""
    /// The library's photos and videos picked in Add photo or video, in the order tapped.
    var libraryPicked: [UUID] = []
    /// Files being brought into the library.
    var isAddingToLibrary = false
    /// The kit whose parts are being chosen before it goes on the video.
    var kitToApply: BrandKit?
    /// The kit open to change (new or saved).
    var kitBeingEdited: BrandKit?
    /// A kit's changes when its sheet closed without Save or Cancel (a swipe down): they come back when it opens again
    /// (`BrandViewModel+KitDraft`, canvas 2 R11).
    var kitDraft: BrandKit?
    /// The open kit is the draft that came back.
    var kitBeingEditedIsDraft = false
    /// Font files are being picked in Files.
    var isImportingFonts = false

    init(
        session: EditorSession, library: MediaLibraryStore, kits: BrandKitStore, fonts: CustomFontStore, fontPacks: FontPackStore,
        styles: TextStyleStoring, writingLanguages: @escaping () -> (script: CueLanguage?, interface: CueLanguage?) = { (nil, nil) }
    ) {
        self.session = session
        self.library = library
        self.kits = kits
        self.fonts = fonts
        self.fontPacks = fontPacks
        self.styles = styles
        self.writingLanguages = writingLanguages
    }
}
