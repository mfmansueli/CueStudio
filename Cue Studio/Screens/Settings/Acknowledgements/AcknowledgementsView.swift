//
//  AcknowledgementsView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Acknowledgements: the fonts Cue ships and the ones it downloads for other scripts, the
/// sample libraries its music and sound effects are played on, the work its
/// code adapts, and the license of each.
struct AcknowledgementsView: View {
    private let sounds = SoundSource.inUse

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
                            Text("SIL Open Font License 1.1").cueFont(.footnote).foregroundStyle(Palette.ink2)
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
                ZStack(alignment: .leading) {
                    NavigationLink {
                        FontPackCreditsView()
                    } label: { EmptyView() }.opacity(0)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fonts for other scripts").foregroundStyle(Palette.ink)
                        Text(verbatim: "Google Fonts · SIL Open Font License 1.1").cueFont(.footnote).foregroundStyle(Palette.ink2)
                    }
                    .frame(minHeight: Metrics.listRowContent, alignment: .leading)
                }
                .accessibilityIdentifier("acknowledgements.fontPacks")
                .cardRowBackground(position: .only)
            } footer: {
                Text("Free fonts for Japanese, Chinese, Korean, Arabic, Hindi and Thai, downloaded the first time a video uses one.")
            }
            Section {
                ForEach(Array(sounds.enumerated()), id: \.element.id) { index, source in
                    ZStack(alignment: .leading) {
                        NavigationLink {
                            LicenseTextView(
                                name: source.library, copyright: "\(source.author)\n\(source.url.absoluteString)", text: source.licenceText
                            )
                        } label: { EmptyView() }.opacity(0)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: source.library).foregroundStyle(Palette.ink)
                            Text(verbatim: source.instruments).cueFont(.footnote).foregroundStyle(Palette.ink2)
                            Text(verbatim: "\(source.author) · \(source.licence.name)").cueFont(.footnote).foregroundStyle(Palette.ink2)
                        }
                        .frame(minHeight: Metrics.listRowContent, alignment: .leading)
                    }
                    .accessibilityIdentifier("acknowledgements.sound.\(source.rawValue)")
                    .cardRowBackground(position: CardRowPosition(index: index, count: sounds.count))
                }
            } footer: {
                Text("Cue’s music and sound effects are played on recordings from these free sample libraries.")
            }
            Section {
                ForEach(Array(CodeCredit.all.enumerated()), id: \.element.id) { index, credit in
                    ZStack(alignment: .leading) {
                        NavigationLink {
                            LicenseTextView(name: credit.name, copyright: credit.copyright, text: credit.licenseText)
                        } label: { EmptyView() }.opacity(0)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: credit.name).foregroundStyle(Palette.ink)
                            Text(verbatim: credit.license).cueFont(.footnote).foregroundStyle(Palette.ink2)
                        }
                        .frame(minHeight: Metrics.listRowContent, alignment: .leading)
                    }
                    .accessibilityIdentifier("acknowledgements.code")
                    .cardRowBackground(position: CardRowPosition(index: index, count: CodeCredit.all.count))
                }
            } footer: {
                Text("Video transitions in Cue's editor build on this open-source work, rewritten for Cue.")
            }
        }
        .cueGroupedList()
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
