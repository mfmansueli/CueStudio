//
//  LicenseTextView.swift
//  Cue Studio
//

import SwiftUI

/// A license, as it ships with Cue: a font's, or that of work Cue's code adapts.
struct LicenseTextView: View {
    let name: String
    let copyright: String
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: copyright).font(.footnote.weight(.semibold))
                Text(verbatim: text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.ink2)
                    .textSelection(.enabled)
            }
            .padding(Metrics.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.bg)
        .navigationTitle(Text(verbatim: name))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("acknowledgements.license")
    }
}
