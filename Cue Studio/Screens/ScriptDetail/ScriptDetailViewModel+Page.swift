//
//  ScriptDetailViewModel+Page.swift
//  Cue Studio
//

import Foundation
import SwiftUI

/// The script page (v26): Draft and Shaped over one set of words, saved as the creator writes.
extension ScriptDetailViewModel {
    /// A selection shorter than this isn't worth a rewrite bar.
    static let minimumSelection = 8
    /// How long a pause in writing is before the words are saved.
    static let commitDelay: Duration = .seconds(1)

    // MARK: - Loading and saving

    /// Opens the page on the script's words. A script with words opens Shaped, as the prototype
    /// does; one being written (new, imported) opens in Draft, the title ready when it has none.
    func loadPage(startsInDraft: Bool) {
        guard let script else { return }
        page.title = script.title
        page.text = script.text
        page.mode = startsInDraft || script.isEmpty ? .draft : .shaped
        page.focusesTitle = script.title.isEmpty && script.isEmpty
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
                ? String(localized: "Saved as v\(script.version + 1) — your take stays with v\(script.version)")
                : String(localized: "Saved as v\(script.version + 1) — \(takeCount) takes stay with v\(script.version)"))
        }
    }

    /// Something was typed: the words are saved when the creator pauses.
    func pageDidEdit() {
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
    }

    // MARK: - Faces

    func setMode(_ mode: ScriptPageMode) {
        guard page.mode != mode, !page.isWriting else { return }
        commitPage()
        page.selection = nil
        page.mode = mode
    }

    /// "✦ Shape": the same words, as sections.
    func shape() {
        setMode(.shaped)
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
        if isLongForPlatform, page.mode == .draft, !page.askedAboutLength {
            page.askedAboutLength = true
            page.showsLengthNudge = true
            return false
        }
        commitPage()
        return true
    }

    // MARK: - Writing

    /// "¶ Cue break": a pause mark where the caret is (over the selection, if there is one).
    func insertCueBreak() {
        var text = page.text
        let place: Range<String.Index>
        if case .selection(let range) = page.selection?.indices {
            place = range
        } else {
            place = text.endIndex..<text.endIndex
        }
        let offset = text.distance(from: text.startIndex, to: place.lowerBound)
        let needsSpace = offset > 0 && !text[text.index(before: place.lowerBound)].isWhitespace
        let insertion = (needsSpace ? " " : "") + "[\(ScriptCue.pause.name)] "
        text.replaceSubrange(place, with: insertion)
        page.text = text
        page.selection = TextSelection(insertionPoint: text.index(text.startIndex, offsetBy: offset + insertion.count))
        pageDidEdit()
    }

    func cycleTextSize() {
        let sizes = ScriptTextSize.allCases
        let next = (sizes.firstIndex(of: page.textSize) ?? 0) + 1
        page.textSize = sizes[next % sizes.count]
    }

    // MARK: - Selection

    /// The selected words, when there are enough of them to be worth a rewrite.
    var selectedText: String? {
        guard case .selection(let range) = page.selection?.indices, !range.isEmpty else { return nil }
        let selected = String(page.text[range])
        return selected.count > Self.minimumSelection ? selected : nil
    }

    /// The four rewrites of the selection: the new words wait for "Use".
    func rewriteSelection(_ action: SelectionAction) async {
        guard let selected = selectedText, case .selection(let range) = page.selection?.indices, !page.isRewriting else { return }
        guard writer.isLanguageModelAvailable else {
            toast.show(writer.unavailableReason ?? String(localized: "AI tools aren't available right now."))
            return
        }
        let start = page.text.distance(from: page.text.startIndex, to: range.lowerBound)
        page.isRewriting = true
        defer { page.isRewriting = false }
        do {
            let rewritten = try await writer.rewrite(selected, with: action.tool, context: rewriteContext)
            page.candidate = RewriteCandidate(
                action: action, original: selected, rewritten: rewritten, offsets: start..<(start + selected.count)
            )
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    func useCandidate() {
        guard let candidate = page.candidate else { return }
        page.text = candidate.applied(to: page.text)
        page.candidate = nil
        page.selection = nil
        commitPage()
    }

    func keepMine() {
        page.candidate = nil
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
        page.mode = .draft
        page.revealed = ""
        let startedAt = ContinuousClock.now
        pageWritingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let generated = try await writer.generate(request)
                guard !Task.isCancelled else { return }
                let returnedAt = ContinuousClock.now
                page.title = generated.title
                await reveal(generated.text)
                guard !Task.isCancelled else { return }
                finishWriting(generated)
                GenerationLog.report(
                    timings: generated.timings, ui: returnedAt.duration(to: .now), total: startedAt.duration(to: .now),
                    requestedWords: ReadTime.words(for: request.targetRange.lowerBound)...ReadTime.words(for: request.targetRange.upperBound),
                    writtenWords: ReadTime.wordCount(in: generated.text)
                )
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                page.isWriting = false
                page.revealed = nil
                page.writingError = error.localizedDescription
            }
        }
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
        }
        // The idea became a script: the card starts empty the next time.
        ideaDraft?.clear()
        if let request { beginVoicePreview(for: request) }
        toast.show(generated.needsFactCheck
            ? String(localized: "Draft ready — check facts before recording")
            : String(localized: "Draft ready — edit anything"))
    }

    /// "Stop": the words that have arrived stay; the rest isn't written.
    func stopWriting() {
        pageWritingTask?.cancel()
        pageWritingTask = nil
        guard page.isWriting else { return }
        page.isWriting = false
        pendingRequest = nil
        // The idea leaves the card only if some of it became a script: stopped before the first word, it stays.
        if let revealed = page.revealed, !revealed.isEmpty {
            page.text = revealed
            ideaDraft?.clear()
        }
        page.revealed = nil
        commitPage()
    }
}
