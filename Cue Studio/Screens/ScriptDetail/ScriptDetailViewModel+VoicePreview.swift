//
//  ScriptDetailViewModel+VoicePreview.swift
//  Cue Studio
//

import Foundation

/// The script as the preview of My Cue Voice: "My Cue Voice | Without", "Sounds like me" and "Adjust".
extension ScriptDetailViewModel {
    /// Whether the strip shows: the script was just written in the creator's voice, and they haven't
    /// said it sounds like them. It is there (waiting) while the words arrive, so the page doesn't move when they're done.
    var showsVoicePreview: Bool {
        page.voicePreview != nil && !profile.profile.voiceApproved
    }

    /// The words on the page: the neutral version while "Without" is chosen.
    var previewedText: String? {
        guard let preview = page.voicePreview, preview.showing == .without else { return nil }
        return preview.without ?? ""
    }

    /// A script written from `request` starts its preview when the voice was in it.
    func beginVoicePreview(for request: ScriptRequest) {
        guard request.voice != nil, !profile.profile.voiceApproved else { return }
        page.voicePreview = VoicePreview(request: request)
    }

    func showVoice(_ showing: VoicePreview.Showing) {
        guard var preview = page.voicePreview, preview.showing != showing else { return }
        preview.showing = showing
        page.voicePreview = preview
        guard showing == .without, preview.without == nil, !preview.isLoadingWithout else { return }
        Task { await loadNeutralVersion() }
    }

    /// The same idea, written with no voice: the other half of the comparison.
    private func loadNeutralVersion() async {
        guard var preview = page.voicePreview else { return }
        preview.isLoadingWithout = true
        page.voicePreview = preview
        var request = preview.request
        request.voice = nil
        let neutral = try? await writer.generate(request).text
        guard var current = page.voicePreview else { return }
        current.isLoadingWithout = false
        current.without = neutral ?? page.text
        page.voicePreview = current
    }

    /// "Sounds like me": the voice is kept, the script's opening is learned from (kept with My Cue Voice, removable in Examples), and the strip goes.
    func approveVoice() {
        profile.profile.voiceApproved = true
        profile.recordApproval(of: page.text)
        page.voicePreview = nil
        // The creator's own choice that went well: ✓ (★ is for what Cue did), the same words as the voice preview's sheet.
        // Kept as how they write, which Apple Intelligence reads on both routes (Ultra AI never gets it; the owner's D1).
        toast.show(String(localized: "Saved · Cue learns from it"))
    }

    func openVoiceAdjust() {
        page.showsVoiceAdjust = true
    }

    /// "Rewrite": the script in the voice with `adjustments` made, for this script only or kept in the profile. `cause` is what was too long
    /// ("Too long" kept in the profile): the field it changes, and what the rewrite makes shorter.
    func rewriteVoice(adjustments: [VoiceAdjustment], keepsInProfile: Bool, cause: TooLongCause? = nil) async {
        page.showsVoiceAdjust = false
        guard !adjustments.isEmpty, writer.isLanguageModelAvailable else { return }
        var context = rewriteContext
        let cause = keepsInProfile && adjustments.contains(.tooLong) ? cause : nil
        let seconds = ReadTime.seconds(for: page.text, language: context.paceLanguage)
        // Kept in the profile, each change is listed in "What Cue learned", where the creator can take it back (the owner's item 11).
        let adjusted = keepsInProfile
            ? profile.keepAdjustments(adjustments, cause: cause, scriptSeconds: seconds)
            : VoiceAdjustment.applying(adjustments, to: profile.profile, cause: cause, scriptSeconds: seconds)
        context.voice = adjusted.voice
        context.shortening = cause
        page.isRewriting = true
        defer { page.isRewriting = false }
        do {
            let text = page.text
            let asked = context
            guard let rewritten = try await touchingUp({ [writer] in try await writer.rewrite(text, with: .inMyVoice, context: asked) }) else {
                return
            }
            page.text = rewritten
            page.voicePreview?.showing = .mine
            page.voicePreview?.without = nil
            commitPage()
            toast.show(keepsInProfile ? String(localized: "Profile updated · New version") : String(localized: "New version"), kind: .cue)
        } catch is CancellationError {
            return
        } catch {
            toast.show(error.localizedDescription, kind: .problem)
        }
    }

    /// The preview ends with the visit: the next time the page opens, the script is just a script.
    func endVoicePreview() {
        page.voicePreview = nil
    }
}
