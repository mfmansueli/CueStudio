//
//  FontPackCreditsView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Acknowledgements › Fonts for other scripts: the families of the script libraries, by script, each with its
/// copyright and licence. They aren't in the app: each downloads the first time a video uses it.
struct FontPackCreditsView: View {
    private let manifest = FontPackManifest.bundled

    var body: some View {
        List {
            ForEach(WritingScript.allCases) { script in
                let packs = manifest.packs(for: script)
                Section {
                    ForEach(Array(packs.enumerated()), id: \.element.id) { index, pack in
                        ZStack(alignment: .leading) {
                            NavigationLink {
                                LicenseTextView(name: pack.family, copyright: pack.copyright, text: FontPack.licenceText)
                            } label: { EmptyView() }.opacity(0)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: pack.family).foregroundStyle(Palette.ink)
                                Text(verbatim: pack.licenceName).cueFont(.footnote).foregroundStyle(Palette.ink2)
                            }
                            .frame(minHeight: Metrics.listRowContent, alignment: .leading)
                        }
                        .accessibilityIdentifier("acknowledgements.fontPack.\(pack.id)")
                        .cardRowBackground(position: CardRowPosition(index: index, count: packs.count))
                    }
                } header: {
                    Text(script.libraryTitle)
                }
            }
        }
        .cueGroupedList()
        .navigationTitle("Fonts for other scripts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
