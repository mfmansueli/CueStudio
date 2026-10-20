//
//  AcknowledgementsView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Acknowledgements: the fonts Cue ships and the work its code adapts, and the license of each.
struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                ForEach(Array(FontCredit.all.enumerated()), id: \.element.id) { index, credit in
                    // The board's list has no chevrons; the license is still one tap away.
                    ZStack(alignment: .leading) {
                        NavigationLink {
                            LicenseTextView(name: credit.name, copyright: credit.copyright, text: credit.licenseText)
                        } label: { EmptyView() }.opacity(0)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: credit.name).foregroundStyle(Palette.ink)
                            Text("SIL Open Font License 1.1").font(.footnote).foregroundStyle(Palette.ink2)
                        }
                        .frame(minHeight: Metrics.listRowContent, alignment: .leading)
                    }
                    .accessibilityIdentifier("acknowledgements.font")
                    .cardRowBackground(position: CardRowPosition(index: index, count: FontCredit.all.count))
                }
            } footer: {
                Text("The free fonts Cue ships with.")
            }
            Section {
                ForEach(Array(CodeCredit.all.enumerated()), id: \.element.id) { index, credit in
                    ZStack(alignment: .leading) {
                        NavigationLink {
                            LicenseTextView(name: credit.name, copyright: credit.copyright, text: credit.licenseText)
                        } label: { EmptyView() }.opacity(0)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: credit.name).foregroundStyle(Palette.ink)
                            Text(verbatim: credit.license).font(.footnote).foregroundStyle(Palette.ink2)
                        }
                        .frame(minHeight: Metrics.listRowContent, alignment: .leading)
                    }
                    .accessibilityIdentifier("acknowledgements.code")
                    .cardRowBackground(position: CardRowPosition(index: index, count: CodeCredit.all.count))
                }
            } footer: {
                Text("Video transitions and Eye Contact in Cue's editor build on these open-source works, rewritten or converted for Cue.")
            }
        }
        .cueGroupedList()
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
