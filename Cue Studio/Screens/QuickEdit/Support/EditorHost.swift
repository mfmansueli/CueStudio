//
//  EditorHost.swift
//  Cue Studio
//

import Foundation

/// What a part of the editor asks of the editor itself through its session (`EditorSession`): whether the preview can play,
/// what is picked and which panel, tab, menu or sheet is open (setting them goes through the editor's own transitions,
/// `QuickEditViewModel.show(_:)` and `pick(_:)`), the take's script, Undo, and where failures are written down.
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
}
