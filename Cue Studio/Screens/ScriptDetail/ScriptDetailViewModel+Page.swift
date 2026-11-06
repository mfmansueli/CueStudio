//
//  ScriptDetailViewModel+Page.swift
//  Cue Studio
//

import Foundation
import SwiftUI

/// The script page (v29): one page of words with a state strip, saved as the creator writes.
extension ScriptDetailViewModel {
    /// A selection shorter than this isn't worth a rewrite bar.
    static let minimumSelection = 8
    /// How long a pause in writing is before the words are saved.
    static let commitDelay: Duration = .seconds(1)
    /// How long the typing pauses before the page's measures catch up with the words (`wordsTyped()`).
    static let typingPause: Duration = .milliseconds(300)
    /// While the typing goes on, the measures catch up at most this often.
    static let typingRefresh: Duration = .milliseconds(1500)

    // MARK: - Loading and saving

    /// Opens the page on the script's words. One being written (a draft opened with "Continue", a new or imported one) takes the
    /// keyboard, in the title when it has none. One the AI is about to write doesn't: the page opens under the idea's star, and a
    /// keyboard there would ride through the transition.
    func loadPage(startsInDraft: Bool) {
        guard let script else { return }
        pageTitle = script.title
        page.text = script.text
        let takesKeyboard = pendingRequest == nil
        page.focusesTitle = takesKeyboard && script.title.isEmpty && script.isEmpty
        page.focusesText = takesKeyboard && startsInDraft && !page.focusesTitle
        page.isLoaded = true
    }

    /// The library changed the words (a tool, a hook): the page follows.
    func syncPage() {
        guard let script, page.isLoaded else { return }
        pageTitle = script.title
        page.text = script.text
        page.selection = nil
    }

    /// Writes what is on the page into the script. Changing the words of a script that has takes
    /// makes a new version, once per visit, so the takes stay tied to what they read.
    func commitPage() {
        pageCommitTask?.cancel()
        pageCommitTask = nil
        guard page.isLoaded, !page.isWriting, let script else { return }
        let titleChanged = pageTitle != script.title
        let textChanged = CueParser.paragraphs(in: page.text) != CueParser.paragraphs(in: script.text)
        guard titleChanged || textChanged else { return }
        if textChanged { voiceQuestions?.noteEdit(ofScript: scriptID) }
        // A new version when the words change after a take was recorded on this one; the edits after it, until the next take, are that
        // same version. Takes saved before versions were kept fall back to once per visit.
        let recorded = scriptTakes
        let takeCount = recorded.count
        let latestTakeVersion = recorded.compactMap(\.scriptVersion).max()
        let bumpsVersion = textChanged && takeCount > 0 && (latestTakeVersion.map { script.version <= $0 } ?? !page.bumpedVersion)
        let title = pageTitle
        let text = textChanged ? page.text : script.text
        library.update(scriptID) { script in
            script.title = title
            script.text = text
            if bumpsVersion { script.version += 1 }
        }
        if titleChanged, let renamed = self.script {
            takes.renameScript(scriptID, to: renamed.displayTitle)
        }
        if bumpsVersion {
            page.bumpedVersion = true
            // Not written (a full iPhone): the app says so (`RootView`), never "Saved as v…".
            guard !library.saveFailed else { return }
            toast.show(takeCount == 1
                ? String(localized: "Saved as v\(script.version + 1) · Take on v\(script.version)")
                : String(localized: "Saved as v\(script.version + 1) · \(takeCount) takes on v\(script.version)"))
        }
    }

    /// Something was typed: the words are saved when the creator pauses.
    func pageDidEdit() {
        // Only once per visit (the words are compared only until then): the page is told again only when something it shows changes.
        if page.isLoaded, !page.isWriting, !page.isEdited || page.isDone,
           page.text != (script?.text ?? "") || pageTitle != (script?.title ?? "") {
            page.isEdited = true
            page.isDone = false
        }
        pageCommitTask?.cancel()
        pageCommitTask = Task { [weak self] in
            try? await Task.sleep(for: Self.commitDelay)
            guard !Task.isCancelled else { return }
            self?.commitPage()
        }
    }

    /// Letters typed in the words (`ScriptPageState.type(_:)`): the page's measures stay on what they last read until the typing pauses
    /// for `typingPause` (or every `typingRefresh` while it goes on), so a letter costs the editor only, never the page around it (the
    /// owner felt each one, on a long script the AI wrote, 03/11/2026).
    func wordsTyped() {
        let now = ContinuousClock.now
        if let since = measuredAt {
            if now - since > Self.typingRefresh {
                page.catchUp()
                measuredAt = now
            }
        } else {
            measuredAt = now
        }
        typingPauseTask?.cancel()
        typingPauseTask = Task { [weak self] in
            try? await Task.sleep(for: Self.typingPause)
            guard !Task.isCancelled, let self else { return }
            page.catchUp()
            measuredAt = nil
        }
        pageDidEdit()
    }

    /// The page goes away (back, or another tab): what was written is kept, a writing in progress stops. Leaving never changes the
    /// script's state (the owner's call, 20/10/2026: Back is how creators leave, and it must not decide that a script is a draft or ready);
    /// only the "Ready to record" switch does, and recording. A recorded script's strip says "Changed since take" after edits.
    /// Leaving: a script that has arrived and is still showing its words is kept whole (it was paid for, and saved already); one still
    /// being asked for stops.
    func leavePage() {
        endVoicePreview()
        if page.isWriting, let arrivedScript {
            pageWritingTask?.cancel()
            finishWriting(arrivedScript, quietly: true)
        } else {
            stopWriting()
        }
        commitPage()
    }

    // MARK: - The strip

    /// What the state strip says, now.
    var strip: ScriptStrip? {
        guard let script else { return nil }
        var current = script
        // The strip reads the words on the page, which may be ahead of what was saved a moment ago (or still arriving): as the page measures
        // them (`measuredText`), so a letter typed never redraws the page around the words.
        if page.isLoaded { current.text = page.isWriting ? (page.revealed ?? "") : measuredText }
        return ScriptStrip(script: current, takes: scriptTakes, isEdited: page.isEdited && !page.isDone)
    }

    /// "✦ Shape": adds cues where they help the delivery, named in the script's language (never changes the words, never changes the state).
    /// Cues hidden on the page come back on, or the toast would name cues nobody can see.
    func shape() {
        guard !page.isWriting else { return }
        let language = script?.language ?? LanguageDetector.language(in: page.text)
        let result = ScriptCueShaper.shaped(page.text, language: language, isSerious: structure.isSerious)
        guard result.added > 0 else { return }
        page.text = result.text
        page.selection = nil
        showsCues = true
        commitPage()
        toast.show(String(localized: "\(result.added) cues added"), kind: .cue)
    }

    /// Done: READY. With no text nothing is saved; with a format's sections still empty it asks first.
    /// The "Ready to record" switch. On: the script is ready (a format with empty sections asks first, an empty page has nothing to make
    /// ready). Off: it is a draft again.
    func setReady(_ ready: Bool) {
        guard !page.isWriting else { return }
        guard !ready else { return done() }
        commitPage()
        library.setFinished(false, of: scriptID)
        Haptics.selection()
    }

    private func done() {
        switch ScriptPageRules.done(text: page.text, type: script?.type) {
        case .nothingToSave:
            toast.show(String(localized: "Nothing to save yet"), kind: .problem)
        case .confirmEmptySections(let count):
            page.emptySectionsToConfirm = count
        case .finish:
            finish()
        }
    }

    /// "Mark ready anyway", or the switch turned on with everything filled in: the switch lights up (`ReadyToggle`) with two soft taps;
    /// a script with no cues is told Shape can add them.
    func finish() {
        page.emptySectionsToConfirm = nil
        commitPage()
        library.setFinished(true, of: scriptID)
        page.isDone = true
        page.isEdited = false
        HapticPatterns.playFinish()
        if strip?.canShape == true { toast.show(String(localized: "Ready to record · Shape adds cues")) }
    }

    /// The length is past what the platform likes: Rec asks once whether to shape it first.
    var isLongForPlatform: Bool {
        guard !page.text.isEmpty else { return false }
        return zone.seconds > preset.idealRange.upperBound
    }

    /// Rec: the question about the length comes once, in the Draft; otherwise it records.
    /// Returns whether to go on and record.
    func recordsNow() -> Bool {
        if isLongForPlatform, !page.askedAboutLength, script?.state(takeCount: scriptTakes.count) != .recorded {
            page.askedAboutLength = true
            page.showsLengthNudge = true
            return false
        }
        commitPage()
        // Recording is using the script as it is: a draft goes to the camera as ready (04 · F2).
        if page.isEdited { page.isDone = true }
        if script?.isFinished == false { library.setFinished(true, of: scriptID) }
        return true
    }

    // MARK: - Writing

    /// The Cues switch by Improve: whether the page draws the cue tags, for every script. The cues stay in the words either way, and
    /// the teleprompter has its own switch (Settings › Prompter).
    var showsCues: Bool {
        get { preferences.showsCuesOnPage }
        set { preferences.showsCuesOnPage = newValue }
    }

    /// The cues bar above the keyboard: the board's four, then the creator's own.
    var barCues: [String] {
        ScriptCue.bar.map(\.name) + preferences.customCues
    }

    /// A cue from the bar above the keyboard, where the caret is: before the selected words, if there are some, which stay (a cue says how to
    /// say them; it never takes their place). One space on each side, never two. With the cues hidden, adding one shows them again: a cue put in
    /// out of sight was only an empty gap in the words (the owner's call, 20/10/2026).
    func insertCue(named name: String) {
        guard !page.isWriting else { return }
        if !showsCues { showsCues = true }
        var text = page.text
        let characters = text.count
        let caret = page.caret.flatMap { ScriptTextOffsets.characters(of: NSRange(location: $0, length: 0), in: page.text) }
        let range = page.selection ?? caret ?? characters..<characters
        let lower = text.index(text.startIndex, offsetBy: min(range.lowerBound, characters))
        let offset = text.distance(from: text.startIndex, to: lower)
        let spaceBefore = offset > 0 && !text[text.index(before: lower)].isWhitespace
        let spaceAfter = lower == text.endIndex || !text[lower].isWhitespace
        let insertion = (spaceBefore ? " " : "") + "[\(name)]" + (spaceAfter ? " " : "")
        text.insert(contentsOf: insertion, at: lower)
        // The cue dropping in is felt.
        Haptics.selection()
        page.text = text
        page.selection = (offset + insertion.count)..<(offset + insertion.count)
        pageDidEdit()
    }

    /// "+" on the cues bar: a cue of the creator's own goes in where the caret was and stays on the bar for every script. One the
    /// bar already has (in any case) just goes in.
    func addCue(_ typed: String) {
        guard let name = ScriptCueName.cleaned(typed) else { return }
        if let existing = barCues.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            insertCue(named: existing)
            return
        }
        preferences.customCues.append(name)
        insertCue(named: name)
    }

    /// One of the creator's cues leaves the bar (the scripts that use it keep it).
    func removeCue(_ name: String) {
        preferences.customCues.removeAll { $0 == name }
    }

    func cycleTextSize() {
        let sizes = ScriptTextSize.allCases
        let next = (sizes.firstIndex(of: page.textSize) ?? 0) + 1
        page.textSize = sizes[next % sizes.count]
    }

    // MARK: - Selection and the AI bar

    /// The selected words, when there are enough of them to be worth a rewrite.
    var selectedText: String? {
        guard let range = page.selection, !range.isEmpty, range.upperBound <= page.text.count else { return nil }
        let text = page.text
        let lower = text.index(text.startIndex, offsetBy: range.lowerBound)
        let upper = text.index(text.startIndex, offsetBy: range.upperBound)
        let selected = String(text[lower..<upper])
        return selected.count > Self.minimumSelection ? selected : nil
    }

    /// The bar over a selection: with Apple Intelligence only, in a language it drafts in (it doesn't exist otherwise), not while the AI
    /// writes the page.
    var showsSelectionBar: Bool {
        selectedText != nil && canDraft && !page.isWriting
    }

    /// Rewrite · Shorter · Punchier · More me change the selected words in place, in violet, and wait for Keep, Undo or Try
    /// again; Cut removes them (with Undo).
    func rewriteSelection(_ action: SelectionAction) async {
        guard let selected = selectedText, let range = page.selection, !page.isRewriting else { return }
        keepPassage()
        guard let tool = action.tool else {
            cut(selected, range: range)
            return
        }
        if let reason = drafting.reason {
            toast.show(reason, kind: .problem)
            return
        }
        page.isRewriting = true
        defer { page.isRewriting = false }
        do {
            var context = rewriteContext
            context.isPassage = true
            let asked = context
            // Stopped (the bar's Stop) or outdated: the words stay as they are.
            guard let result = try await touchingUp({ [writer] in try await writer.rewriteReported(selected, with: tool, context: asked) }) else {
                return
            }
            // The tool couldn't do what it says to these words: they stay, and the creator is told, instead of a "change" that changes nothing.
            guard !result.isUntouched, result.text != selected else {
                sayResult(
                    String(localized: "Couldn’t draft it"), kind: .problem, action: retrySelection(action, range: range),
                    about: script?.displayTitle ?? ""
                )
                return
            }
            replace(range, with: result.text, action: action, original: selected)
        } catch is CancellationError {
            return
        } catch {
            let again = ScriptFailureNotice.isWorthRetrying(error) ? retrySelection(action, range: range) : nil
            sayResult(Self.failureMessage(for: error), kind: .problem, action: again, about: script?.displayTitle ?? "")
        }
    }

    /// "Try again" after a selection's rewrite failed: the same words, picked again, and the same change asked of them, while the page is
    /// still there and its words still reach that far.
    private func retrySelection(_ action: SelectionAction, range: Range<Int>) -> ToastAction? {
        retry { viewModel in
            guard range.upperBound <= viewModel.page.text.count else { return }
            viewModel.page.selection = range
            await viewModel.rewriteSelection(action)
        }
    }

    /// Puts the AI's words where the old ones were and holds them as the passage.
    private func replace(_ range: Range<Int>, with rewritten: String, action: SelectionAction, original: String) {
        var text = page.text
        let characters = text.count
        guard range.upperBound <= characters else { return }
        let lower = text.index(text.startIndex, offsetBy: range.lowerBound)
        let upper = text.index(text.startIndex, offsetBy: range.upperBound)
        text.replaceSubrange(lower..<upper, with: rewritten)
        page.text = text
        page.passage = AIPassage(action: action, original: original, replacement: rewritten, range: range.lowerBound..<(range.lowerBound + rewritten.count))
        page.selection = nil
        pageDidEdit()
    }

    /// Cut, like a deletion on the page: a cue it cuts into goes whole (`ScriptCueDeletion`), and the words around it keep one space between
    /// them. Undo puts the page back as it was.
    private func cut(_ selected: String, range: Range<Int>) {
        let before = page.text
        page.text = Self.cutting(range, from: before)
        page.selection = nil
        pageDidEdit()
        toast.show(String(localized: "Cut"), action: ToastAction(title: String(localized: "Undo")) { [weak self] in
            guard let self else { return }
            page.text = before
            pageDidEdit()
        })
    }

    /// `text` without the characters in `range`, a cue it cuts into whole, and no doubled space where they were.
    nonisolated static func cutting(_ range: Range<Int>, from text: String) -> String {
        var characters = Array(text)
        let lower = min(range.lowerBound, characters.count)
        characters.removeSubrange(lower..<min(range.upperBound, characters.count))
        var cut = String(characters)
        var at = lower
        if let whole = ScriptCueDeletion.completing(from: text, to: cut) {
            cut = whole.text
            at = whole.caret
        }
        var result = Array(cut)
        if at > 0, at < result.count, result[at] == " ", result[at - 1] == " " || result[at - 1] == "\n" {
            result.remove(at: at)
        } else if at < result.count, at == 0, result[at] == " " {
            result.remove(at: at)
        }
        return String(result)
    }

    /// ✓ Keep, or a tap outside: the new words are the creator's. The AI changed them, so claims reviewed before are to be checked again.
    func keepPassage() {
        let kept = page.passage != nil
        page.passage = nil
        commitPage()
        if kept { library.flagForFactCheckAfterRewrite(scriptID) }
    }

    /// ↺ Undo: the old words come back.
    func undoPassage() {
        guard let passage = page.passage else { return }
        page.text = passage.undone(in: page.text)
        page.passage = nil
        pageDidEdit()
    }

    /// ✦ Try again: the old words go back and the same change is asked of them once more.
    func retryPassage() async {
        guard let passage = page.passage else { return }
        let range = passage.range
        let action = passage.action
        undoPassage()
        let end = range.lowerBound + passage.original.count
        page.selection = range.lowerBound..<end
        await rewriteSelection(action)
    }
}

// MARK: - The AI writing into the page

extension ScriptDetailViewModel {
    /// Words that arrive per step while the model's answer is shown.
    static let wordsPerStep = 4
    /// The title's head start on the words under it.
    static let titleLead: Duration = .milliseconds(450)

    /// A script opened from the card's arrow: the words are written into the page, in violet,
    /// the title first, with Stop within reach.
    func beginWritingIfNeeded() {
        // A request that failed is let go (`write`): coming back to the page never starts the model by itself.
        guard let request = pendingRequest, !page.isWriting else { return }
        write(request)
    }

    func write(_ request: ScriptRequest) {
        pendingRequest = request
        page.isWriting = true
        page.revealed = ""
        // The star says how much is written while it waits; the page's pill says it when there is no star.
        let meter = WritingProgressMeter(for: request)
        page.progress = meter
        transition?.track(meter)
        let startedAt = ContinuousClock.now
        arrivedScript = nil
        // A script asked for keeps writing for the few seconds iOS allows after Cue leaves (Ultra AI takes up to a minute).
        let endGrace = writingGrace()
        pageWritingTask = Task { [weak self] in
            defer { endGrace() }
            guard let self else { return }
            do {
                var generated = try await generate(request, reporting: meter)
                guard !Task.isCancelled else { return }
                // In paragraphs, a blank line between them: easier to read, and each one arrives as a piece short enough to draw.
                generated.text = ScriptParagraphs.arranged(generated.text)
                meter.finish()
                // Saved as it arrives: the star and the words arriving only show it, and a Cue that iOS closes meanwhile keeps the script.
                keepArrived(generated)
                let returnedAt = ContinuousClock.now
                // The star opens the page (ring, crossfade) before the first word is written.
                await transition?.contentReady()
                guard !Task.isCancelled else { return }
                pageTitle = generated.title
                // The voice question compares with Apple Intelligence's own rewrites: not on an Ultra AI script.
                if request.engine == .apple { beginVoicePreview(for: request) }
                // The title arrives first, word by word (`ScriptPageHeader`), then the words under it.
                if revealPause > .zero { try? await Task.sleep(for: Self.titleLead) }
                await reveal(generated.text)
                guard !Task.isCancelled else { return }
                // The last words finish arriving before the page becomes the editor (which takes over in a crossfade, `ScriptPageView`).
                if revealPause > .zero { try? await Task.sleep(for: .seconds(ArrivingText.settleTime)) }
                guard !Task.isCancelled else { return }
                finishWriting(generated)
                let asked = request.targetRange
                let low = ReadTime.words(for: asked.lowerBound, language: request.language)
                GenerationLog.report(
                    timings: generated.timings, ui: returnedAt.duration(to: .now), total: startedAt.duration(to: .now),
                    requestedWords: low...max(low, ReadTime.words(for: asked.upperBound, language: request.language)),
                    writtenWords: ReadTime.wordCount(in: generated.text)
                )
            } catch {
                // Only the page's own cancel (Stop, Cancel, leaving) is quiet. A request the system ended by itself is a failure like
                // any other: otherwise the star would wait for a script that never comes.
                guard !Task.isCancelled else { return }
                page.progress = nil
                if let transition, transition.isActive {
                    // The star leaves the way Cancel does: no page, the idea kept, and a toast says why.
                    page.isWriting = false
                    page.revealed = nil
                    // "Try again" (`ScriptStarter`) sends the same idea again, with a new star: this page is gone with it.
                    transition.fail(saying: Self.failureMessage(for: error), canRetry: ScriptFailureNotice.isWorthRetrying(error))
                    return
                }
                // No star (a page asked to write without one; every request from the app has its star): the same words in a toast,
                // and the page is the creator's to write in. Asking again is the star's Try again, from where the idea was sent.
                page.isWriting = false
                page.revealed = nil
                pendingRequest = nil
                if script?.awaitsDraft == true { library.update(scriptID) { $0.awaitsDraft = false } }
                toast.showResult(Self.failureMessage(for: error), kind: .problem)
            }
        }
    }

    /// Apple Intelligence writes the page, or Ultra when the creator chose it for this idea: never one standing in for the other.
    private func generate(_ request: ScriptRequest, reporting meter: WritingProgressMeter) async throws -> GeneratedScript {
        guard request.engine == .ultra else { return try await writer.generate(request, reporting: meter) }
        guard let ultra else { throw UltraError.notAvailable }
        return try await ultra.generate(request, reporting: meter)
    }

    /// What a failed write says: the reason when it is one the creator can act on (another language,
    /// waiting), otherwise that it couldn't (its toast carries "Try again"). Ultra's failures always say what happened (`UltraError`).
    static func failureMessage(for error: any Error) -> String {
        ScriptFailureNotice.message(for: error)
    }

    /// "Try again" after an error: the same idea, once more.
    private func reveal(_ text: String) async {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        var shown = 0
        while shown < words.count, !Task.isCancelled {
            shown = min(words.count, shown + Self.wordsPerStep)
            page.revealed = words.prefix(shown).joined(separator: " ")
            if revealPause > .zero { try? await Task.sleep(for: revealPause) }
        }
    }

    /// The script as the model wrote it, in the library before its words are shown (the fact check is in place around them).
    private func keepArrived(_ generated: GeneratedScript) {
        arrivedScript = generated
        library.update(scriptID) { script in
            script.title = generated.title
            script.text = generated.text
            script.factCheck = generated.needsFactCheck
            if generated.engine == .ultra { script.draftedBy = .ultra }
            // The AI drafts for the creator: what it writes is a draft until they switch it to "Ready to record" (the owner's call,
            // 20/10/2026).
            script.isFinished = false
            script.awaitsDraft = false
        }
    }

    /// - Parameter quietly: left before the words finished arriving: no taps and no toast for a page that is gone.
    private func finishWriting(_ generated: GeneratedScript, quietly: Bool = false) {
        let request = pendingRequest
        arrivedScript = nil
        page.text = generated.text
        page.revealed = nil
        page.progress = nil
        page.isWriting = false
        pageWritingTask = nil
        pendingRequest = nil
        // Written: two soft taps as the page becomes the creator's.
        if !quietly { HapticPatterns.playFinish() }
        if request?.voice != nil { voiceQuestions?.recordVoiceScript(scriptID) }
        if !quietly { prewriteNeutralVersion() }
        draftLearning?.noteDraft(generated.text, for: scriptID)
        guard !quietly else { return }
        toast.show(generated.engine == .ultra
            ? String(localized: "Ultra AI draft ready · Check facts")
            : generated.needsFactCheck
            ? String(localized: "Draft ready · Check facts")
            : String(localized: "Draft ready · Edit anything"), kind: .cue)
    }

    /// "Stop": the words that have arrived stay; the rest isn't written.
    func stopWriting() {
        pageWritingTask?.cancel()
        pageWritingTask = nil
        guard page.isWriting else { return }
        page.isWriting = false
        arrivedScript = nil
        // Stopped by the creator: the page is theirs now, whatever it holds.
        if script?.awaitsDraft == true { library.update(scriptID) { $0.awaitsDraft = false } }
        pendingRequest = nil
        // A script stopped halfway isn't the one to judge the voice by.
        page.voicePreview = nil
        // What arrived is the page's (the dock it came from started over when the script was saved, `ScriptStarter`).
        if let revealed = page.revealed, !revealed.isEmpty {
            page.text = revealed
        }
        page.revealed = nil
        page.progress = nil
        commitPage()
    }
}
