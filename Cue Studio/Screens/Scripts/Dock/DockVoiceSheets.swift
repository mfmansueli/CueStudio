//
//  DockVoiceSheets.swift
//  Cue Studio
//

import SwiftUI

/// The AI card's two My Cue Voice sheets (the owner, 03/11/2026): the guided questions (✦ Voice, or "Continue answering") and the invitation
/// the first idea sent with questions still open shows, once (`VoiceInviteSheet`). The idea stays in the field through both. Opened from
/// the invitation, the questions end on "✦ Draft my script" and the idea then goes as the arrow would have sent it; opened from ✦ Voice,
/// the last question writes the typed idea, if there is one, and an idea in a language Apple Intelligence can't draft in ends on "Done".
///
/// The card presents them itself: its content is always dark, and a sheet shown from in there would not follow the screen.
struct DockVoiceSheets: ViewModifier {
    @Binding var setup: VoiceSetupSheet.Mode?
    @Binding var showsInvite: Bool
    /// The typed idea, when Apple Intelligence can draft it: ✦ Voice's questions write it at the end.
    let typedIdea: () -> String?
    /// The idea the arrow was sending (typed, else the suggestion), when Apple Intelligence can draft it.
    let waitingIdea: () -> String?
    /// Writes the typed idea (✦ Voice's questions).
    let write: () -> Void
    /// Sends the idea as the arrow does, past the invitation.
    let send: () -> Void

    @Environment(CreatorProfileService.self) private var profile
    /// What the creator chose on the invitation, done once it has gone: true answers first, false writes now, nil (swiped away) does
    /// nothing and the idea waits in the field.
    @State private var answersFirst: Bool?
    /// The questions came from the invitation: finishing them sends the waiting idea.
    @State private var resumesSend = false
    /// The questions ended on "✦ Draft my script": the idea goes once they are gone, from the arrow as always.
    @State private var sendsWhenGone = false

    func body(content: Content) -> some View {
        content
            .sheet(item: $setup, onDismiss: questionsGone) { mode in
                VoiceSetupSheet(mode: mode, profile: profile.profile, ideaText: resumesSend ? waitingIdea() : typedIdea()) { writesScript in
                    guard writesScript else { return }
                    if resumesSend { sendsWhenGone = true } else { write() }
                }
            }
            .sheet(isPresented: $showsInvite, onDismiss: invitationGone) {
                VoiceInviteSheet(onAnswer: { answersFirst = true }, onWrite: { answersFirst = false })
            }
    }

    private func invitationGone() {
        let choice = answersFirst
        answersFirst = nil
        switch choice {
        case true?:
            resumesSend = true
            setup = .missing
        case false?:
            send()
        case nil:
            break
        }
    }

    private func questionsGone() {
        resumesSend = false
        guard sendsWhenGone else { return }
        sendsWhenGone = false
        send()
    }
}
