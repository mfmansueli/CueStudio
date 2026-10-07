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

    // MARK: - Loading and saving

    /// Opens the page on the script's words. One being written (a draft opened with "Continue", a new or imported one) takes the
    /// keyboard, in the title when it has none. One the AI is about to write doesn't: the page opens under the idea's star, and a
    /// keyboard there would ride through the transition.
    func loadPage(startsInDraft: Bool) {
        guard let script else { return }
        page.title = script.title
        page.text = script.text
        let takesKeyboard = pendingRequest == nil
        page.focusesTitle = takesKeyboard && script.title.isEmpty && script.isEmpty
        page.focusesText = takesKeyboard && startsInDraft && !page.focusesTitle
        page.isLoaded = true
    }

    /// The library changed the words (a tool, a hook, the full editor): the page follows.
    func syncPage() {
        guard let script, page.isLoaded else { return }
        page.title = script.title
        page.text = script.text
        page.selection = nil
    }

    /// Writes what is on the page into the script. Changing the words of a script that has takes
    /// makes a new version, once per visit, so the takes stay tied to what they read.
    func commitPage() {
        pageCommitTask?.cancel()
        pageCommitTask = nil
        guard page.isLoaded, !page.isWriting, let script else { return }
        let titleChanged = page.title != script.title
        let textChanged = CueParser.paragraphs(in: page.text) != CueParser.paragraphs(in: script.text)
        guard titleChanged || textChanged else { return }
        if textChanged { voiceQuestions?.noteEdit(ofScript: scriptID) }
        let takeCount = scriptTakes.count
        let bumpsVersion = textChanged && takeCount > 0 && !page.bumpedVersion
        let title = page.title
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
            toast.show(takeCount == 1
                ? String(localized: "Saved as v\(script.version + 1) · Take on v\(script.version)")
                : String(localized: "Saved as v\(script.version + 1) · \(takeCount) takes on v\(script.version)"))
        }
    }

    /// Something was typed: the words are saved when the creator pauses.
    func pageDidEdit() {
        if page.isLoaded, !page.isWriting, page.text != (script?.text ?? "") || page.title != (script?.title ?? "") {
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

    /// The page goes away (back, or another tab): what was written is kept, a writing in progress stops.
    func leavePage() {
        endVoicePreview()
        stopWriting()
        commitPage()
        leaveAsDraftIfEdited()
    }

    /// Leaving after edits without Done: a script that isn't recorded becomes a draft, once, with a toast (04 · F2).
    /// A recorded script stays recorded and its strip says "Changed since take".
    func leaveAsDraftIfEdited() {
        guard let script, page.isEdited, !page.isDone else { return }
        page.isEdited = false
        guard ScriptPageRules.leavesAsDraft(state: script.state(takeCount: scriptTakes.count), wasEdited: true) else { return }
        if script.isFinished { library.setFinished(false, of: scriptID) }
        toast.show(String(localized: "Saved as draft"))
    }

    // MARK: - The strip

    /// What the state strip says, now.
    var strip: ScriptStrip? {
        guard let script else { return nil }
        var current = script
        // The strip reads the words on the page, which may be ahead of what was saved a moment ago (or still arriving).
        if page.isLoaded { current.text = page.isWriting ? (page.revealed ?? "") : page.text }
        return ScriptStrip(script: current, takes: scriptTakes, hasAI: writer.isLanguageModelAvailable, isEdited: page.isEdited && !page.isDone)
    }

    /// "✦ Shape": adds cues where they help the delivery (never changes the words, never changes the state).
    func shape() {
        guard !page.isWriting else { return }
        let result = ScriptCueShaper.shaped(page.text)
        guard result.added > 0 else { return }
        page.text = result.text
        page.selection = nil
        commitPage()
        toast.show(String(localized: "\(result.added) cues added"))
    }

    /// Done: READY. With no text nothing is saved; with a format's sections still empty it asks first.
    func done() {
        guard !page.isWriting else { return }
        switch ScriptPageRules.done(text: page.text, type: script?.type) {
        case .nothingToSave:
            toast.show(String(localized: "Nothing to save yet"))
        case .confirmEmptySections(let count):
            page.emptySectionsToConfirm = count
        case .finish:
            finish()
        }
    }

    /// "Done anyway", or Done with everything filled in.
    func finish() {
        page.emptySectionsToConfirm = nil
        commitPage()
        library.setFinished(true, of: scriptID)
        page.isDone = true
        page.isEdited = false
        toast.show(strip?.canShape == true
            ? String(localized: "Ready to record · Shape adds cues")
            : String(localized: "Ready to record"))
    }

    // MARK: - Reading

    /// What the Shaped face shows: the words as sections, with the advice.
    var shaped: ScriptShape {
        ScriptShape(text: page.text, structure: structure, speed: preferences.prompter.speed)
    }

    /// The tip for a section, unless the creator waved it off.
    func visibleTip(_ tip: ScriptShape.Tip?) -> ScriptShape.Tip? {
        guard let tip, !page.dismissedTips.contains(tip.id) else { return nil }
        return tip
    }

    func dismiss(_ tip: ScriptShape.Tip) {
        page.dismissedTips.insert(tip.id)
    }

    /// "Fix" and "Split": the words change in the Draft, so the creator can see it.
    func apply(_ tip: ScriptShape.Tip) {
        switch tip {
        case .longHook:
            page.text = ScriptShape.shortenedHook(in: page.text)
        case .longSentence(let sentence):
            page.text = ScriptShape.splitting(sentence, in: page.text)
        }
        commitPage()
    }

    /// "✦ No CTA yet · Suggest one".
    func suggestCTA() {
        page.text = ScriptShape.addingCTA(to: page.text)
        commitPage()
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

    /// A cue from the bar above the keyboard, where the caret is (over the selection, if there is one).
    func insertCue(_ cue: ScriptCue) {
        guard !page.isWriting else { return }
        var text = page.text
        let characters = text.count
        let range = page.selection ?? characters..<characters
        let lower = text.index(text.startIndex, offsetBy: min(range.lowerBound, characters))
        let upper = text.index(text.startIndex, offsetBy: min(range.upperBound, characters))
        let offset = text.distance(from: text.startIndex, to: lower)
        let needsSpace = offset > 0 && !text[text.index(before: lower)].isWhitespace
        let insertion = (needsSpace ? " " : "") + "[\(cue.name)] "
        text.replaceSubrange(lower..<upper, with: insertion)
        page.text = text
        page.selection = (offset + insertion.count)..<(offset + insertion.count)
        pageDidEdit()
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

    /// The bar over a selection: with Apple Intelligence only (it doesn't exist without it), not while the AI writes the page.
    var showsSelectionBar: Bool {
        selectedText != nil && writer.isLanguageModelAvailable && !page.isWriting
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
        guard writer.isLanguageModelAvailable else {
            toast.show(writer.unavailableReason ?? String(localized: "AI isn't available now"))
            return
        }
        page.isRewriting = true
        defer { page.isRewriting = false }
        do {
            let result = try await writer.rewriteReported(selected, with: tool, context: rewriteContext)
            // The tool couldn't do what it says to these words: they stay, and the creator is told, instead of a "change" that changes nothing.
            guard !result.isUntouched, result.text != selected else {
                toast.show(String(localized: "Couldn’t write it · Try again"))
                return
            }
            replace(range, with: result.text, action: action, original: selected)
        } catch is CancellationError {
            return
        } catch {
            toast.show(Self.failureMessage(for: error))
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

    private func cut(_ selected: String, range: Range<Int>) {
        var text = page.text
        let lower = text.index(text.startIndex, offsetBy: range.lowerBound)
        let upper = text.index(text.startIndex, offsetBy: range.upperBound)
        text.removeSubrange(lower..<upper)
        page.text = text
        page.selection = nil
        pageDidEdit()
        toast.show(String(localized: "Cut"), action: ToastAction(title: String(localized: "Undo")) { [weak self] in
            guard let self else { return }
            var restored = page.text
            let spot = restored.index(restored.startIndex, offsetBy: min(range.lowerBound, restored.count))
            restored.insert(contentsOf: selected, at: spot)
            page.text = restored
            pageDidEdit()
        })
    }

    /// ✓ Keep, or a tap outside: the new words are the creator's.
    func keepPassage() {
        page.passage = nil
        commitPage()
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

    /// A script opened from the card's arrow: the words are written into the page, in violet,
    /// the title first, with Stop within reach.
    func beginWritingIfNeeded() {
        // After an error the page waits for "Try again": coming back to it doesn't start the model by itself.
        guard let request = pendingRequest, !page.isWriting, page.writingError == nil else { return }
        write(request)
    }

    func write(_ request: ScriptRequest) {
        pendingRequest = request
        page.writingError = nil
        page.isWriting = true
        page.revealed = ""
        let startedAt = ContinuousClock.now
        pageWritingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let generated = try await writer.generate(request)
                guard !Task.isCancelled else { return }
                let returnedAt = ContinuousClock.now
                // The star opens the page (ring, crossfade) before the first word is written.
                await transition?.contentReady()
                guard !Task.isCancelled else { return }
                page.title = generated.title
                // What the written page shows around the words is in place before they arrive: the fact check and the voice question.
                if generated.needsFactCheck { library.update(scriptID) { $0.factCheck = true } }
                beginVoicePreview(for: request)
                await reveal(generated.text)
                guard !Task.isCancelled else { return }
                finishWriting(generated)
                GenerationLog.report(
                    timings: generated.timings, ui: returnedAt.duration(to: .now), total: startedAt.duration(to: .now),
                    requestedWords: ReadTime.words(for: request.targetRange.lowerBound)...ReadTime.words(for: request.targetRange.upperBound),
                    writtenWords: ReadTime.wordCount(in: generated.text)
                )
            } catch {
                // Only the page's own cancel (Stop, Cancel, leaving) is quiet. A request the system ended by itself is a failure like
                // any other: otherwise the star would wait for a script that never comes.
                guard !Task.isCancelled else { return }
                if let transition, transition.isActive {
                    // The star leaves the way Cancel does: no page, the idea kept, and a toast says why.
                    page.isWriting = false
                    page.revealed = nil
                    transition.fail()
                    toast.show(Self.failureMessage(for: error))
                    return
                }
                page.isWriting = false
                page.revealed = nil
                page.writingError = error.localizedDescription
            }
        }
    }

    /// What a failed write says: the reason when it is one the creator can act on (another language,
    /// waiting), otherwise "Try again".
    static func failureMessage(for error: any Error) -> String {
        if let error = error as? ScriptAIError, error.explainsItself { return error.localizedDescription }
        return String(localized: "Couldn’t write it · Try again")
    }

    /// "Try again" after an error: the same idea, once more.
    func retryWriting() {
        guard let request = pendingRequest else { return }
        write(request)
    }

    private func reveal(_ text: String) async {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        var shown = 0
        while shown < words.count, !Task.isCancelled {
            shown = min(words.count, shown + Self.wordsPerStep)
            page.revealed = words.prefix(shown).joined(separator: " ")
            if revealPause > .zero { try? await Task.sleep(for: revealPause) }
        }
    }

    private func finishWriting(_ generated: GeneratedScript) {
        let request = pendingRequest
        page.text = generated.text
        page.revealed = nil
        page.isWriting = false
        pageWritingTask = nil
        pendingRequest = nil
        library.update(scriptID) { script in
            script.title = generated.title
            script.text = generated.text
            script.factCheck = generated.needsFactCheck
            // The AI delivered a complete script: it is READY to record (04 · F2).
            script.isFinished = true
        }
        // The idea became a script: the card starts empty the next time.
        ideaDraft?.clear()
        if request?.voice != nil { voiceQuestions?.recordVoiceScript(scriptID) }
        toast.show(generated.needsFactCheck
            ? String(localized: "Draft ready · Check facts")
            : String(localized: "Draft ready · Edit anything"))
    }

    /// "Stop": the words that have arrived stay; the rest isn't written.
    func stopWriting() {
        pageWritingTask?.cancel()
        pageWritingTask = nil
        guard page.isWriting else { return }
        page.isWriting = false
        pendingRequest = nil
        // A script stopped halfway isn't the one to judge the voice by.
        page.voicePreview = nil
        // The idea leaves the card only if some of it became a script: stopped before the first word, it stays.
        if let revealed = page.revealed, !revealed.isEmpty {
            page.text = revealed
            ideaDraft?.clear()
        }
        page.revealed = nil
        commitPage()
    }
}
