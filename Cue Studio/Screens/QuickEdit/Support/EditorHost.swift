//
//  EditorHost.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// What a part of the editor asks of the editor itself through its session (`EditorSession`): whether the preview can play,
/// what is picked and which panel, tab, menu or sheet is open (setting them goes through the editor's own transitions,
/// `QuickEditViewModel.show(_:)` and `pick(_:)`), the take's script, Undo, where failures are written down, showing again what
/// the preview plays (a comparison started or ended), and a photo or video brought in from the library with its progress pill.
@MainActor
protocol EditorHost: AnyObject {
    var isReady: Bool { get }
    var selection: EditorSelection? { get set }
    var panel: EditorPanel? { get set }
    var panelTab: EditorPanelTab { get set }
    var toolMenu: EditorToolMenu? { get set }
    var sheet: EditorSheet? { get set }
    var captionScript: Script? { get }
    func undo()
    func noteFailure(_ error: any Error, _ operation: String)
    /// What the preview plays changed (a comparison started or ended): the player shows it again.
    func showPlayedEdit()
    /// The picked photo or video copied in, with how far it got said over the preview; Cancel stops it with
    /// `CancellationError`.
    func importPicked(_ item: PhotosPickerItem) async throws -> ImportedMedia
}
