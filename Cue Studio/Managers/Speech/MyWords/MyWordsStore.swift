//
//  MyWordsStore.swift
//  Cue Studio
//

import Foundation

/// My words in UserDefaults, on this iPhone, as a list of strings. Read fresh each time, so the editor and the recognizers that
/// hold the same store see the same list. What can't be read as a list of words (another type, a damaged value) reads as an
/// empty list; entries that couldn't be added (empty, too long, repeated, past the limit) are left out when read.
@MainActor
final class MyWordsStore: MyWordsStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var words: MyWordsList {
        get {
            guard let stored = defaults.array(forKey: DefaultsKey.myWords) else { return MyWordsList() }
            return MyWordsList(stored.compactMap { $0 as? String })
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: DefaultsKey.myWords)
            } else {
                defaults.set(newValue.words, forKey: DefaultsKey.myWords)
            }
        }
    }
}
