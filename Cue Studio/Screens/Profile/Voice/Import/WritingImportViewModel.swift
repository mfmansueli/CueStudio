//
//  WritingImportViewModel.swift
//  Cue Studio
//

import Foundation
import Observation

/// "Import my writing": what the creator brings, what Cue reads of it and what they accept. Three steps: bring texts, wait while Cue reads them
/// (the numbers first, then Apple Intelligence on this iPhone when it can), and review what it heard. Nothing is saved before the review is accepted.
@MainActor
@Observable
final class WritingImportViewModel {
    enum Step: Equatable {
        case collect, reading, review
    }

    /// What is happening while Cue reads.
    enum Stage: Equatable {
        case counting, askingModel
    }

    private(set) var step: Step = .collect
    private(set) var stage: Stage = .counting
    /// The text typed or pasted and not yet added.
    var draft = ""
    /// The creator says these are their own words.
    var isOwn = false
    private(set) var pieces: [WritingPiece] = []
    private(set) var proposal = WritingImportProposal()
    /// Files that could not be read, for the line under the list.
    private(set) var skippedFiles = 0
    /// Nothing usable was in what they pasted.
    private(set) var pasteWasEmpty = false

    private let reader: any WritingStyleReading
    private var work: Task<Void, Never>?

    init(reader: any WritingStyleReading) {
        self.reader = reader
    }

    // MARK: - Bringing texts

    /// The sources in the list, in the order they were added, with how many texts each gave.
    var sources: [(name: String, count: Int)] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for piece in pieces {
            let name = piece.source ?? ""
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 0) }
    }

    var wordCount: Int { pieces.reduce(0) { $0 + $1.wordCount } }

    /// Habits (phrases, openings, endings) need a few texts.
    var needsMoreForHabits: Bool { !pieces.isEmpty && pieces.count < WritingAnalyzer.minimumPiecesForHabits }

    var canRead: Bool { isOwn && !pieces.isEmpty }

    /// Apple Intelligence would also read the style (it is on, ready and not busy), not only the numbers.
    var canUseModel: Bool { reader.canRead(language: nil) }

    /// Adds what is in `draft` as one or more texts.
    func addDraft(source: String) {
        let added = WritingCleaner.pieces(from: draft, source: source)
        pasteWasEmpty = added.isEmpty && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !added.isEmpty else { return }
        append(added)
        draft = ""
    }

    func addFiles(_ urls: [URL]) async {
        let result = await Task.detached { WritingFileReader.read(urls) }.value
        skippedFiles = result.skipped
        append(result.pieces)
    }

    func remove(source: String) {
        pieces.removeAll { ($0.source ?? "") == source }
    }

    private func append(_ added: [WritingPiece]) {
        var seen = Set(pieces.map { VoiceTextValidator.key(String($0.text.prefix(120))) })
        let fresh = added.filter { seen.insert(VoiceTextValidator.key(String($0.text.prefix(120)))).inserted }
        pieces = Array((pieces + fresh).prefix(WritingCleaner.maximumPieces))
    }

    // MARK: - Reading

    /// Reads the texts: the numbers, then (when the model is ready) what it makes of how they sound. Ends in the review, whatever the model does.
    func read(against profile: CreatorProfile) {
        guard canRead, step == .collect else { return }
        step = .reading
        stage = .counting
        let pieces = pieces
        work = Task { [weak self] in
            let analysis = await Task.detached { WritingAnalyzer.analyze(pieces) }.value
            guard let self, !Task.isCancelled else { return }
            var reading: StyleReading?
            if reader.canRead(language: analysis.language), !analysis.excerpts.isEmpty {
                stage = .askingModel
                reading = await reader.read(analysis.excerpts.map(\.text), language: analysis.language)
            }
            guard !Task.isCancelled else { return }
            proposal = WritingImportProposalBuilder.build(analysis: analysis, reading: reading, profile: profile)
            step = .review
        }
    }

    /// Stops reading and goes back to the texts.
    func cancelReading() {
        work?.cancel()
        work = nil
        step = .collect
    }

    /// Back from the review to the texts, which are kept.
    func backToTexts() {
        step = .collect
    }

    /// Leaves one excerpt out of what is kept.
    func removeExcerpt(_ id: UUID) {
        proposal.excerpts.removeAll { $0.id == id }
    }

    func toggle(_ kind: WritingFinding.Kind) {
        guard let index = proposal.findings.firstIndex(where: { $0.id == kind }) else { return }
        proposal.findings[index].isOn.toggle()
    }
}
