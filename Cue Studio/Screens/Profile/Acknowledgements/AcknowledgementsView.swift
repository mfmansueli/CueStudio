//
//  AcknowledgementsView.swift
//  Cue Studio
//

import SwiftUI

/// Profile › Acknowledgements: the fonts Cue ships, what each is for, and its license.
struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                ForEach(FontCredit.all) { credit in
                    NavigationLink {
                        LicenseTextView(credit: credit)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: credit.name).foregroundStyle(Palette.ink)
                            Text(credit.use).font(.footnote).foregroundStyle(Palette.ink2)
                            Text("SIL Open Font License 1.1").font(.caption).foregroundStyle(Palette.ink3)
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("acknowledgements.font")
                }
            } header: {
                Text("Fonts")
            } footer: {
                Text("These fonts are free to use and embed under the SIL Open Font License.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
