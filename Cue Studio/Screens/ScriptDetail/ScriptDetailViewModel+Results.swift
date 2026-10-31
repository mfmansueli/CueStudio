//
//  ScriptDetailViewModel+Results.swift
//  Cue Studio
//

import Foundation

/// What comes of the page's AI tools, which take a while: a result never takes the place of a toast with a button (`ToastService.showResult`:
/// the Undo of a script deleted meanwhile stays within reach), and one that arrives after the creator left the page names the script it was
/// for, without a "Try again" whose page is gone.
extension ScriptDetailViewModel {
    /// "TikTok version of “Morning habits” saved": a version (or a translation) that arrived off the page.
    static func versionSaved(_ name: String, of title: String) -> String {
        String(localized: "\(name) version of “\(title)” saved")
    }

    /// Says what came of a tool for the script titled `title`. Off the page, `away` (or the message after the script's title) says it.
    func sayResult(
        _ message: String, kind: ToastKind = .cue, action: ToastAction? = nil, ending work: UUID? = nil, about title: String,
        away: String? = nil
    ) {
        guard !isOnScreen else {
            toast.showResult(message, kind: kind, action: action, ending: work)
            return
        }
        toast.showResult(away ?? String(localized: "“\(title)” · \(message)"), kind: kind, action: action, ending: work)
    }

    /// An AI tool failed: the reason in Cue's words (`ScriptFailureNotice`), with "Try again" when asking again may work and the page is still
    /// there. Stopping it is not a failure and says nothing.
    func sayFailure(
        _ error: any Error, ending work: UUID? = nil, about title: String,
        again: @escaping @MainActor (ScriptDetailViewModel) async -> Void
    ) {
        guard !(error is CancellationError) else { return }
        let action = ScriptFailureNotice.isWorthRetrying(error) ? retry(again) : nil
        sayResult(ScriptFailureNotice.message(for: error), kind: .problem, action: action, ending: work, about: title)
    }

    /// "Try again" on a failed tool's toast: the same tool, on the same script, once more. None once the page is gone (its context with it):
    /// the Undo of a rewrite still goes with a result off the page, as it puts the old words back wherever the creator is.
    func retry(_ again: @escaping @MainActor (ScriptDetailViewModel) async -> Void) -> ToastAction? {
        guard isOnScreen else { return nil }
        return ToastAction(title: String(localized: "Try again")) { [weak self] in
            guard let self else { return }
            Task { await again(self) }
        }
    }
}
