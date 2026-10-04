//
//  ScriptTakesStrip.swift
//  Cue Studio
//

import SwiftUI

/// The takes made from this script, under the Shaped page: a row of thumbnails that open the review.
struct ScriptTakesStrip: View {
    let takes: [Take]
    let version: Int
    let onOpen: (Take) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Takes").font(.title3.bold())
                Spacer()
                Group {
                    if takes.count == 1 {
                        Text("1 take · v\(version)")
                    } else {
                        Text("\(takes.count) takes · v\(version)")
                    }
                }
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(takes) { take in
                        Button { onOpen(take) } label: {
                            TakeTile(take: take, width: 96, height: 170)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("page.takes")
    }
}
