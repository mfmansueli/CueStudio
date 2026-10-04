//
//  ScriptDetailViewModel+VoicePreview.swift
//  Cue Studio
//

import Foundation

/// The script as the preview of My Cue Voice: "My Cue Voice | Without", "Sounds like me" and "Adjust".
extension ScriptDetailViewModel {
    /// Whether the strip shows: the script was just written in the creator's voice, and they haven't
    /// said it sounds like them.
    var showsVoicePreview: Bool {
        page.voicePreview != nil && !profile.profile.voiceApproved && !page.isWriting
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

    /// "Sounds like me": the voice is kept, and the strip goes.
    func approveVoice() {
        profile.profile.voiceApproved = true
        page.voicePreview = nil
        toast.show(String(localized: "Got it — Cue will keep writing like this"))
    }

    func openVoiceAdjust() {
        page.showsVoiceAdjust = true
    }

    /// "Rewrite": the script in the voice with `adjustments` made, for this script only or kept in the profile.
    func rewriteVoice(adjustments: [VoiceAdjustment], keepsInProfile: Bool) async {
        page.showsVoiceAdjust = false
        guard !adjustments.isEmpty, writer.isLanguageModelAvailable else { return }
        let adjusted = VoiceAdjustment.applying(adjustments, to: profile.profile)
        if keepsInProfile { profile.profile = adjusted }
        var context = rewriteContext
        context.voice = adjusted.voice
        page.isRewriting = true
        defer { page.isRewriting = false }
        do {
            let rewritten = try await writer.rewrite(page.text, with: .inMyVoice, context: context)
            page.text = rewritten
            page.voicePreview?.showing = .mine
            page.voicePreview?.without = nil
            commitPage()
            toast.show(keepsInProfile ? String(localized: "Profile updated · script rewritten") : String(localized: "Script rewritten"))
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    /// The preview ends with the visit: the next time the page opens, the script is just a script.
    func endVoicePreview() {
        page.voicePreview = nil
    }
}
