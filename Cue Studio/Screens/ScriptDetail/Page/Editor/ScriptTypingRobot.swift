//
//  ScriptTypingRobot.swift
//  Cue Studio
//

#if DEBUG
import UIKit

/// Debug, `-uiTestAutoType`: types a sentence into the script's words at a person's pace (a letter every 90 ms, a breath of 350 ms after
/// each word), through the same path the keyboard takes (`insertText`), so `ScriptTypingProbe` measures what typing costs the app with
/// nothing else asking it anything. XCTest's own typing reads the whole text view between two words, which a long script makes slow and
/// a person never does. Starts a second after the words take the keyboard.
@MainActor
final class ScriptTypingRobot {
    static var isAsked: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestAutoType") }

    static let sentence = "e depois mais uma linha para ver se a escrita flui bem agora "

    private weak var view: UITextView?
    private var task: Task<Void, Never>?

    init(view: UITextView) {
        self.view = view
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            for letter in Self.sentence {
                guard !Task.isCancelled, let view = self?.view else { return }
                // Asked first, as the keyboard's typing asks (`insertText` alone doesn't).
                let range = [NSValue(range: view.selectedRange)]
                if view.delegate?.textView?(view, shouldChangeTextInRanges: range, replacementText: String(letter)) ?? true {
                    view.insertText(String(letter))
                }
                try? await Task.sleep(for: letter == " " ? .milliseconds(350) : .milliseconds(90))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
#endif
