//
//  Text+Joined.swift
//  Cue Studio
//

import SwiftUI

extension Text {
    /// Pieces of text one after another as one `Text`, each keeping its own font, colour and custom attributes (the words a renderer
    /// animates one by one).
    ///
    /// One flat interpolation of all the pieces. Nesting them one in the next (`Text("\(text)\(piece)")`, piece after piece) is
    /// resolved recursively, a level per piece: a long script ran the main thread out of stack while it was being written (crash
    /// reports from an iPhone 15 Pro, October 2026).
    static func joined(_ pieces: [Text]) -> Text {
        var interpolation = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: pieces.count)
        for piece in pieces { interpolation.appendInterpolation(piece) }
        return Text(LocalizedStringKey(stringInterpolation: interpolation))
    }
}
