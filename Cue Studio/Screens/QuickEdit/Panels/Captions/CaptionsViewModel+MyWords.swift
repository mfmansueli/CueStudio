//
//  CaptionsViewModel+MyWords.swift
//  Cue Studio
//

import Foundation

/// My words (`MyWordsSheet`, Captions › •••, and Add to my words in Find and replace): the creator's names and terms, which speech
/// recognition listens for in new captions and recordings (`RecognitionHints`). Kept on this iPhone apart from My Cue Voice. Saving
/// a word never changes this video's captions and is no undo step; Replace in Find and replace never saves a word.
extension CaptionsViewModel {
    /// Opens My words over the editor (the video stops).
    func openMyWords() {
        player.pause()
        toolMenu = nil
        myWords = myWordsStore.words
        sheet = .myWords
    }

    /// Saves `text` at the top of My words, as typed (`MyWordsList.cleaned`).
    @discardableResult
    func addToMyWords(_ text: String) -> MyWordsList.Addition {
        var list = myWordsStore.words
        let addition = list.add(text)
        switch addition {
        case .added, .respelled:
            keepMyWords(list)
            Haptics.selection()
        case .alreadyThere, .full, .invalid:
            myWords = list
        }
        return addition
    }

    /// `old` written as `text` instead. False when it can't be saved (empty, too long): the list stays as it was.
    @discardableResult
    func changeMyWord(_ old: String, to text: String) -> Bool {
        var list = myWordsStore.words
        guard list.change(old, to: text) != nil else { return false }
        keepMyWords(list)
        return true
    }

    func deleteMyWord(_ word: String) {
        var list = myWordsStore.words
        list.remove(word)
        keepMyWords(list)
    }

    func deleteMyWords(atOffsets offsets: IndexSet) {
        var list = myWords
        list.remove(atOffsets: offsets)
        keepMyWords(list)
    }

    // MARK: - From Find and replace

    /// The spelling Find and replace's "Add to my words" saves, shown on the button before it is tapped: what is typed in
    /// Replace with (the correct spelling the creator is putting in the video), else what is typed in Find (a word the creator
    /// looked for, already right). Nil when neither can be saved.
    func myWordsSpelling(find query: String, replacement: String) -> String? {
        let replaced = MyWordsList.cleaned(replacement)
        let word = replaced.isEmpty ? MyWordsList.cleaned(query) : replaced
        return MyWordsList.isValid(word) ? word : nil
    }

    /// Whether `spelling` is already in My words exactly so (the button then says so instead of offering to add it).
    func isInMyWords(_ spelling: String) -> Bool {
        myWords.entry(matching: spelling) == spelling
    }

    /// "Add to my words" in Find and replace: saves `spelling` (`myWordsSpelling`), and only that: the captions stay as they are.
    func addFindSpellingToMyWords(_ spelling: String) {
        switch addToMyWords(spelling) {
        case .added(let word):
            toast.show(String(localized: "“\(word)” added to My words"))
        case .respelled(let word):
            toast.show(String(localized: "Saved as “\(word)” in My words"))
        case .alreadyThere(let word):
            toast.show(String(localized: "“\(word)” is already in My words"))
        case .full:
            toast.show(String(localized: "My words is full · Delete one to add another"), kind: .problem)
        case .invalid:
            break
        }
    }

    private func keepMyWords(_ list: MyWordsList) {
        myWordsStore.words = list
        myWords = list
    }
}
