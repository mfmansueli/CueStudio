//
//  MyWordsStoring.swift
//  Cue Studio
//

import Foundation

/// Where My words are kept between launches (`MyWordsList`): read by speech recognition before it listens (captions, Voice
/// Following, dictation) and changed from the editor's Captions › My words and Find and replace.
@MainActor
protocol MyWordsStoring: AnyObject {
    var words: MyWordsList { get set }
}
