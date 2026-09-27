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
    var sheet: AppSheet?
    var prompter: PrompterLaunch?

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

    func closePrompter() {
        prompter = nil
    }
}
