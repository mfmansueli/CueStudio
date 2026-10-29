//
//  UltraTitleAccents.swift
//  Cue Studio
//

import Foundation

/// The model sometimes writes the title without the accents its own script has ("Celular ou camera para gravar videos" over a script that says
/// "câmera" and "vídeos"; "manhas" for "manhãs"), measured on the iPhone on 29/10/2026. A title word takes the script's spelling when the script
/// has that word only with its accents; a word the script also writes plain ("e" beside "é") is left as it is.
nonisolated enum UltraTitleAccents {
    static func restored(_ title: String, from script: String) -> String {
        var spellings: [String: Set<String>] = [:]
        script.enumerateSubstrings(in: script.startIndex..., options: .byWords) { word, _, _, _ in
            guard let word = word?.lowercased() else { return }
            spellings[folded(word), default: []].insert(word)
        }
        var result = title
        var replacements: [(Range<String.Index>, String)] = []
        title.enumerateSubstrings(in: title.startIndex..., options: .byWords) { word, range, _, _ in
            guard let word, folded(word) == word.lowercased(), let found = spellings[folded(word)], found.count == 1,
                  let accented = found.first, accented != word.lowercased() else { return }
            replacements.append((range, cased(accented, like: word)))
        }
        for (range, word) in replacements.reversed() { result.replaceSubrange(range, with: word) }
        return result
    }

    private static func folded(_ word: String) -> String {
        word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// `word` with `model`'s capitals: all capitals, a capital first letter, or as it is.
    private static func cased(_ word: String, like model: String) -> String {
        if model.count > 1, model == model.uppercased() { return word.uppercased() }
        if model.first?.isUppercase == true { return word.prefix(1).uppercased() + word.dropFirst() }
        return word
    }
}
