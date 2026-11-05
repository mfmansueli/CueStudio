//
//  ScriptDetailViewModel+VoicePreview.swift
//  Cue Studio
//

import Foundation

/// The script as the preview of My Cue Voice: "My voice | Without", "Sounds like me" and "Adjust".
extension ScriptDetailViewModel {
    /// Whether the strip shows: the script was just written in the creator's voice, and Cue still wants to hear whether it sounds like them
    /// (`CreatorProfile.wantsVoiceCheck`). It is there (waiting) while the words arrive, so the page doesn't move when they're done.
    var showsVoicePreview: Bool {
        page.voicePreview != nil && profile.profile.wantsVoiceCheck
    }

    /// The words on the page while "Without" is chosen and written: only to read, side by side in time with the voiced ones.
    var previewedText: String? {
        guard let preview = page.voicePreview, preview.showing == .without else { return nil }
        return preview.without
    }

    /// "Without" is on the page (or being written): the page is only to compare, so its tools, its state and its edits wait.
    var isComparing: Bool { page.voicePreview?.showing == .without && showsVoicePreview }

    /// A script written from `request` starts its preview when the voice was in it.
    func beginVoicePreview(for request: ScriptRequest) {
        guard request.voice != nil, profile.profile.wantsVoiceCheck else { return }
        page.voicePreview = VoicePreview(request: request)
    }

    /// The voiced script has arrived: its neutral twin is written now, on this iPhone, so "Without" opens at once. Apple Intelligence costs
    /// nothing (an Ultra AI script never has the preview); a tool the creator starts meanwhile goes first (`pauseNeutralVersion()`).
    func prewriteNeutralVersion() {
        guard showsVoicePreview, let preview = page.voicePreview, preview.without == nil, !preview.isLoadingWithout else { return }
        neutralTask = Task { await loadNeutralVersion() }
    }

    func showVoice(_ showing: VoicePreview.Showing) {
        guard var preview = page.voicePreview, preview.showing != showing else { return }
        Haptics.selection()
        preview.showing = showing
        page.voicePreview = preview
        guard showing == .without, preview.without == nil, !preview.isLoadingWithout else { return }
        neutralTask = Task { await loadNeutralVersion() }
    }

    /// A tool takes the model: the neutral version written in the background stops, and is written again if "Without" is asked for.
    func pauseNeutralVersion() {
        guard let neutralTask, page.voicePreview?.showing != .without else { return }
        neutralTask.cancel()
        self.neutralTask = nil
        page.voicePreview?.isLoadingWithout = false
    }

    /// The same idea, written with no voice: the other half of the comparison, in paragraphs as the voiced one is. When it can't be written,
    /// the page goes back to the creator's voice and says so (never the same words shown as "Without").
    private func loadNeutralVersion() async {
        guard var preview = page.voicePreview else { return }
        preview.isLoadingWithout = true
        page.voicePreview = preview
        var request = preview.request
        request.voice = nil
        let neutral: String?
        do {
            neutral = try await writer.generate(request).text
        } catch {
            neutral = nil
        }
        guard !Task.isCancelled, var current = page.voicePreview else { return }
        neutralTask = nil
        current.isLoadingWithout = false
        guard let neutral, !neutral.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let wasAsked = current.showing == .without
            current.showing = .mine
            page.voicePreview = current
            if wasAsked {
                toast.show(String(localized: "Couldn’t write it without your voice · Try again"), kind: .problem)
            }
            return
        }
        current.without = ScriptParagraphs.arranged(neutral)
        page.voicePreview = current
        if current.showing == .without { Haptics.soft() }
    }

    /// "Sounds like me": the voiced script (back on the page if "Without" was showing) is approved, its opening learned from (kept with My Cue
    /// Voice, removable in What Cue learned), and the strip goes. The toast says what was kept.
    func approveVoice() {
        neutralTask?.cancel()
        neutralTask = nil
        let learned = profile.recordApproval(of: page.text)
        profile.profile.voiceApproved = true
        page.voicePreview = nil
        // The creator's own choice that went well: ✓ (★ is for what Cue did).
        toast.show(learned ? String(localized: "Saved · Cue learns from it") : String(localized: "Noted · Too short to learn from"))
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
        page.voicePreview?.showing = .mine
        page.isRewriting = true
        defer { page.isRewriting = false }
        do {
            let text = page.text
            let asked = context
            guard let rewritten = try await touchingUp({ [writer] in try await writer.rewrite(text, with: .inMyVoice, context: asked) }) else {
                return
            }
            page.text = rewritten
            // The neutral version doesn't depend on the voice: it stays for the next comparison.
            page.voicePreview?.showing = .mine
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
        neutralTask?.cancel()
        neutralTask = nil
        page.voicePreview = nil
    }
}
