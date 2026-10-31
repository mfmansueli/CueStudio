//
//  ScriptLibraryOffer.swift
//  Cue Studio
//

import Foundation

/// Which script libraries a font picker shows, beside the Latin families (which always come first): the scripts the words being
/// styled are written in, and the scripts of the creator's languages (the captions' language, the script language, the app's).
/// A creator who works only in Latin languages never sees one, nor downloads anything.
nonisolated enum ScriptLibraryOffer {
    static func scripts(styling text: String, captionLanguage: CueLanguage?, scriptLanguage: CueLanguage?, interfaceLanguage: CueLanguage?) -> [WritingScript] {
        let languages = [captionLanguage, scriptLanguage, interfaceLanguage].compactMap(\.self)
        var scripts = WritingScript.scripts(in: text, han: WritingScript.hanReading(for: languages))
        for language in languages {
            if let script = WritingScript.of(language), !scripts.contains(script) { scripts.append(script) }
        }
        return scripts
    }
}
