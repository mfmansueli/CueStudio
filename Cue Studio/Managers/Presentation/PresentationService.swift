//
//  PresentationService.swift
//  Cue Studio
//

import Foundation

/// App-wide navigation state, so any screen can open a script, the prompter or a creation sheet
/// without knowing who presents it.
@MainActor
@Observable
final class PresentationService {
    var selectedTab: AppTab = .scripts
    var scriptsPath: [ScriptRoute] = []
    var profilePath: [ProfileRoute] = []
    var sheet: AppSheet?
    var prompter: PrompterLaunch?
    /// This device is the remote of a teleprompter on another one.
    var showsRemoteController = false

    // MARK: - Actions

    func openScript(_ id: UUID, editing: Bool = false) {
        sheet = nil
        selectedTab = .scripts
        scriptsPath = [ScriptRoute(scriptID: id, startsEditing: editing)]
    }

    func openPrompter(scriptID: UUID?, mode: PrompterMode) {
        sheet = nil
        prompter = PrompterLaunch(scriptID: scriptID, mode: mode)
    }

    func openReview(of take: Take) {
        sheet = nil
        prompter = PrompterLaunch(scriptID: take.scriptID, mode: .selfie, reviewTakeID: take.id)
    }

    func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }

    /// Tab bar selection. Record is not a destination: it opens "Start recording" and the current
    /// tab stays selected.
    func select(_ tab: AppTab) {
        if tab == .record {
            present(.startRecording)
        } else {
            selectedTab = tab
        }
    }

    func closePrompter() {
        prompter = nil
    }

    /// Full screen, over everything: a remote only needs its buttons.
    func openRemoteController() {
        sheet = nil
        prompter = nil
        showsRemoteController = true
    }
}
