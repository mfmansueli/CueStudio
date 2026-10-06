//
//  AcknowledgementsView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Acknowledgements: the fonts Cue ships, and the license of each.
struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                ForEach(FontCredit.all) { credit in
                    // The board's list has no chevrons; the license is still one tap away.
                    ZStack(alignment: .leading) {
                        NavigationLink { LicenseTextView(credit: credit) } label: { EmptyView() }.opacity(0)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: credit.name).foregroundStyle(Palette.ink)
                            Text("SIL Open Font License 1.1").font(.footnote).foregroundStyle(Palette.ink2)
                        }
                        .frame(minHeight: Metrics.listRowContent, alignment: .leading)
                    }
                    .accessibilityIdentifier("acknowledgements.font")
                    .cardRowBackground()
                }
            } footer: {
                Text("The free fonts Cue ships with.")
            }
        }
        .cueGroupedList()
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
