//
//  AnswerCommentViewModel.swift
//  Cue Studio
//

import Foundation
import ImageIO
import SwiftUI

/// "Answer a comment": a screenshot (or the copied words) of a question from the audience becomes the next script.
/// Vision reads the screenshot on this iPhone; the creator confirms the comment, its author and the platform before
/// anything is written, and the script is written in their voice like any other.
@MainActor
@Observable
final class AnswerCommentViewModel {
    enum Step: Equatable { case choose, reading, confirm }

    private(set) var step: Step = .choose
    var author = ""
    var text = ""
    var platform: Platform
    private(set) var failure: String?

    private let recognizer: TextRecognizing
    private let clipboard: () -> String?
    private let starter: (ScriptComment, Platform) -> Void
    /// "Write it myself": a blank draft with the comment kept (the only way without Apple Intelligence).
    private let writesByHand: ((ScriptComment, Platform) -> Void)?
    /// "Save to Logbook": keeps the comment as an idea for later.
    private let savesToLogbook: ((String) -> Void)?

    init(
        defaultPlatform: Platform, recognizer: TextRecognizing, clipboard: @escaping () -> String?,
        starter: @escaping (ScriptComment, Platform) -> Void,
        writesByHand: ((ScriptComment, Platform) -> Void)? = nil, savesToLogbook: ((String) -> Void)? = nil
    ) {
        platform = defaultPlatform
        self.recognizer = recognizer
        self.clipboard = clipboard
        self.starter = starter
        self.writesByHand = writesByHand
        self.savesToLogbook = savesToLogbook
    }

    /// The words are enough to write from.
    var canWrite: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - Choosing

    /// A screenshot of the comment, read by Vision on this iPhone.
    func read(imageData: Data) async {
        step = .reading
        failure = nil
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fail(String(localized: "That picture can’t be opened."))
            return
        }
        do {
            let document = try await recognizer.recognizeText(in: [image])
            fill(CommentParser.parse(document.text))
        } catch {
            fail(String(localized: "Cue couldn’t find any words in that picture. You can paste the comment instead."))
        }
    }

    /// The comment, copied from the app.
    func pasteFromClipboard() {
        failure = nil
        guard let copied = clipboard(), !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            failure = String(localized: "Copy the comment first, then paste it here.")
            return
        }
        fill(CommentParser.parse(copied))
    }

    private func fill(_ parsed: CommentParser.Parsed) {
        author = parsed.author ?? ""
        text = parsed.text
        step = .confirm
    }

    private func fail(_ message: String) {
        failure = message
        step = .choose
    }

    func startOver() {
        step = .choose
        failure = nil
    }

    // MARK: - Writing

    func write() {
        guard canWrite else { return }
        let name = author.trimmingCharacters(in: .whitespaces)
        let handle = name.isEmpty ? nil : (name.hasPrefix("@") ? name : "@" + name)
        starter(ScriptComment(author: handle, text: text.trimmingCharacters(in: .whitespacesAndNewlines), platform: platform), platform)
    }

    private var comment: ScriptComment? {
        guard canWrite else { return nil }
        let name = author.trimmingCharacters(in: .whitespaces)
        let handle = name.isEmpty ? nil : (name.hasPrefix("@") ? name : "@" + name)
        return ScriptComment(author: handle, text: text.trimmingCharacters(in: .whitespacesAndNewlines), platform: platform)
    }

    var offersLogbook: Bool { savesToLogbook != nil }
    var offersWritingByHand: Bool { writesByHand != nil }

    func writeMyself() {
        guard let comment else { return }
        writesByHand?(comment, platform)
    }

    /// The comment, as an idea waiting in the Logbook.
    func saveForLater() {
        guard let comment else { return }
        savesToLogbook?(comment.author.map { "\($0): \(comment.text)" } ?? comment.text)
    }

    /// What the model is asked: an answer to the comment, spoken to the person who wrote it.
    static func idea(for comment: ScriptComment) -> String {
        let who = comment.author.map { " from \($0)" } ?? ""
        return "Answer this comment\(who) from my audience, speaking to them directly: “\(comment.text)”"
    }
}
