//
//  PresentationService.swift
//  Cue Studio
//

import Foundation
import SwiftUI

/// App-wide navigation state, so any screen can open a script, the prompter or a creation sheet
/// without knowing who presents it.
@MainActor
@Observable
final class PresentationService {
    var selectedTab: AppTab = .scripts
    var scriptsPath: [ScriptRoute] = []
    var settingsPath: [SettingsRoute] = []
    /// The Profile tab's pages opened from elsewhere (a notification's "Your universe").
    var profilePath: [ProfileRoute] = []
    /// The Logbook note to bring into view when the Logbook opens (a notification about it); the Logbook clears it.
    var logbookFocus: UUID?
    var sheet: AppSheet?
    /// Takes opens filtered this way (from "Your universe"); Takes takes it and clears it.
    var takesRequest: TakesRequest?
    var prompter: PrompterLaunch?
    /// The take whose review is on screen (`TakeReviewView` sets it): a notification about that take doesn't open it a second time, which
    /// came back after the creator closed it (B18).
    var reviewOnScreen: UUID?
    /// Cue Pro over the whole app, from somewhere that isn't a sheet (the dock's writer chip when Ultra AI's free scripts are used up).
    var paywall: PaywallContext?
    /// This device is the remote of a teleprompter on another one.
    var showsRemoteController = false
    /// How many screens ask for the tab bar to be out of the way (the script page, a list in selection mode).
    private(set) var tabBarHiders = 0

    /// The floating tab bar is hidden while a screen asks for it.
    var hidesTabBar: Bool { tabBarHiders > 0 }

    func hideTabBar() { tabBarHiders += 1 }

    func showTabBar() { tabBarHiders = max(0, tabBarHiders - 1) }

    // MARK: - Actions

    /// Opens the script's page. `animated: false` puts it there without the push: under the idea's star, where nobody sees it come.
    func openScript(_ id: UUID, editing: Bool = false, writing: ScriptRequest? = nil, animated: Bool = true) {
        sheet = nil
        selectedTab = .scripts
        let path = [ScriptRoute(scriptID: id, startsEditing: editing || writing != nil, writing: writing)]
        if animated {
            scriptsPath = path
        } else {
            withoutAnimation { scriptsPath = path }
        }
    }

    /// Back to Scripts' list from whatever is open on it. `animated: false` for a page taken away under the idea's star.
    func showScriptsList(animated: Bool = true) {
        if animated {
            scriptsPath = []
        } else {
            withoutAnimation { scriptsPath = [] }
        }
    }

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    /// - Parameter platform: the network to record for (a Retake of a video keeps its own); nil, the script's.
    func openPrompter(scriptID: UUID?, mode: PrompterMode, platform: Platform? = nil) {
        sheet = nil
        prompter = PrompterLaunch(scriptID: scriptID, mode: mode, platform: platform)
    }

    func openReview(of take: Take, then action: ReviewLaunchAction? = nil) {
        sheet = nil
        // Already there: the export it tells about, or the queue's "Continue posting" card, is on the review the creator sees.
        guard reviewOnScreen != take.id || !(action == nil || action == .continueQueue) else { return }
        prompter = PrompterLaunch(scriptID: take.scriptID, mode: .selfie, platform: take.platform, reviewTakeID: take.id, reviewAction: action)
    }

    /// "See in Takes ›": the videos shared to a platform, or of a theme, in a year.
    func openTakes(_ request: TakesRequest) {
        sheet = nil
        takesRequest = request
        selectedTab = .takes
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
