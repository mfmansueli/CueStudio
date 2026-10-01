//
//  QuickEditViewModel+Translation.swift
//  Cue Studio
//

import Foundation

/// Captions in other languages, translated on the iPhone (Apple's Translation framework, nothing
/// sent anywhere, nothing paid per use): sentence by sentence for context, kept apart from the
/// original, corrected by hand, and marked outdated when the original changes. Whether a pair can
/// be translated is asked each time; when it can't, the translation can still be written by hand.
extension QuickEditViewModel {
    /// The language the captions are in: what speech recognition heard, the language picked for
    /// them, or what their text reads as.
    var captionSourceLanguage: Locale.Language? {
        if let code = edit.captionTranscript?.languageCode { return Locale.Language(identifier: code) }
        if let language = edit.captionLanguage { return language.locale.language }
        let text = edit.captions.map(\.text).joined(separator: " ")
        return LanguageDetector.dominantLanguageCode(in: text).map { Locale.Language(identifier: $0) }
    }

    /// Languages to translate into: every language Cue knows but the captions' own.
    var translationTargets: [CueLanguage] {
        let source = captionSourceLanguage?.languageCode?.identifier
        return CueLanguage.allCases.filter { $0.languageCode != source }
    }

    func translation(_ language: CueLanguage) -> CaptionTranslation? {
        edit.captionTranslations.first { $0.language == language }
    }

    /// Lines of `language`'s translation whose original changed since.
    func outdatedLines(_ language: CueLanguage) -> [TranslatedCaptionLine] {
        translation(language)?.outdatedLines(against: edit.captions) ?? []
    }

    /// Asks whether this iPhone can translate the captions into `target`, then hands the request to
    /// the view's translation task. `replacingRevised` translates corrected lines again too;
    /// `shows` shows the captions in `target` when done.
    func translateCaptions(to target: CueLanguage, replacingRevised: Bool = false, shows: Bool = false) async {
        guard isReady, !translationState.isWorking, !edit.captions.isEmpty else { return }
        guard let source = captionSourceLanguage else {
            translationState = .unknownSource
            return
        }
        translationState = .checking
        let support = await translations.support(from: source, to: target.locale.language)
        guard support != .unsupported else {
            let name = Locale.interface.localizedString(forLanguageCode: source.languageCode?.identifier ?? "") ?? source.maximalIdentifier
            translationState = .unsupported(source: name, target: target)
            return
        }
        translationState = .translating
        translationRequest = TranslationRequest(source: source, target: target, replacingRevised: replacingRevised, shows: shows)
    }

    /// The view's translation task gave a session for `request`: translates every sentence and
    /// keeps the result as one undo step. A request that was replaced or stopped meanwhile is
    /// dropped.
    func performTranslation(_ request: TranslationRequest, with session: CaptionTranslationSession) async {
        guard translationRequest == request else { return }
        let captions = edit.captions
        let sentences = CaptionTranslationBuilder.sentences(from: captions)
        do {
            let translated = try await session.translate(sentences.map(CaptionTranslationBuilder.text(of:)))
            guard translationRequest == request, !isClosed else { return }
            let lines = zip(translated, sentences).flatMap { CaptionTranslationBuilder.lines($0, for: $1) }
            let merged = CaptionTranslationBuilder.merged(
                lines, keeping: translation(request.target), captions: captions, replacingRevised: request.replacingRevised
            )
            change { snapshot in
                var translations = snapshot.captionTranslations ?? []
                translations.removeAll { $0.language == request.target }
                translations.append(CaptionTranslation(language: request.target, lines: merged))
                snapshot.captionTranslations = translations
                if request.shows { snapshot.captionDisplay = .translation(request.target) }
            }
            translationRequest = nil
            translationState = .idle
            toast.show(String(localized: "Captions translated to \(request.target.localizedName)"))
        } catch is CancellationError {
            guard translationRequest == request else { return }
            translationRequest = nil
            translationState = .idle
        } catch {
            guard translationRequest == request else { return }
            translationRequest = nil
            translationState = .failed
        }
    }

    /// Stops translating; what was there stays.
    func cancelTranslation() {
        translationRequest = nil
        translationState = .idle
    }

    /// A translation to write by hand (when this iPhone can't translate the pair, or by choice):
    /// one empty line over each original line.
    func writeTranslation(_ language: CueLanguage) {
        guard translation(language) == nil else { return }
        let lines = edit.captions.map { cue in
            TranslatedCaptionLine(
                cueIDs: [cue.id], sourceText: cue.text, text: "", start: cue.start, end: cue.end, sourceID: cue.sourceID, isRevised: true
            )
        }
        change { snapshot in
            var translations = snapshot.captionTranslations ?? []
            translations.append(CaptionTranslation(language: language, lines: lines))
            snapshot.captionTranslations = translations
        }
        translationState = .idle
    }

    /// A corrected (or written) translated line.
    func setTranslatedText(_ language: CueLanguage, line id: UUID, _ text: String) {
        change { snapshot in
            guard var translations = snapshot.captionTranslations,
                  let index = translations.firstIndex(where: { $0.language == language }),
                  let line = translations[index].lines.firstIndex(where: { $0.id == id }) else { return }
            translations[index].lines[line].text = text
            translations[index].lines[line].isRevised = true
            snapshot.captionTranslations = translations
        }
    }

    /// The translated line now reads as its original does now: no longer outdated.
    func markTranslationCurrent(_ language: CueLanguage, line id: UUID) {
        let byID = Dictionary(edit.captions.map { ($0.id, $0) }) { first, _ in first }
        change { snapshot in
            guard var translations = snapshot.captionTranslations,
                  let index = translations.firstIndex(where: { $0.language == language }),
                  let line = translations[index].lines.firstIndex(where: { $0.id == id }) else { return }
            let originals = translations[index].lines[line].cueIDs.compactMap { byID[$0] }
            translations[index].lines[line].sourceText = CaptionText.joined(originals.map(\.text))
            snapshot.captionTranslations = translations
        }
    }

    func deleteTranslation(_ language: CueLanguage) {
        change { snapshot in
            snapshot.captionTranslations?.removeAll { $0.language == language }
            if snapshot.captionDisplay?.language == language { snapshot.captionDisplay = .original }
        }
    }

    /// Which captions show (and export): one undo step.
    func setCaptionDisplay(_ display: CaptionDisplay) {
        change { $0.captionDisplay = display }
    }
}
