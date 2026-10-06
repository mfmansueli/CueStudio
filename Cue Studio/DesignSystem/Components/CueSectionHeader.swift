//
//  CueSectionHeader.swift
//  Cue Studio
//

import SwiftUI

/// The header of a section of a grouped list: small, bold capitals in the quiet ink, as the boards draw it (the system's own header is
/// larger and in title case since iOS 26).
struct CueSectionHeader: View {
    private let text: Text

    init(_ key: LocalizedStringKey) {
        text = Text(key)
    }

    init(verbatim string: String) {
        text = Text(verbatim: string)
    }

    var body: some View {
        text
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(Palette.ink2)
    }
}
