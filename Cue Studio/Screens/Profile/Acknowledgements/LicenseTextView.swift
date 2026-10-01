//
//  LicenseTextView.swift
//  Cue Studio
//

import SwiftUI

/// A font's license, as it ships with Cue.
struct LicenseTextView: View {
    let credit: FontCredit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: credit.copyright).font(.footnote.weight(.semibold))
                Text(verbatim: credit.licenseText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.ink2)
                    .textSelection(.enabled)
            }
            .padding(Metrics.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.bg)
        .navigationTitle(Text(verbatim: credit.name))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("acknowledgements.license")
    }
}
