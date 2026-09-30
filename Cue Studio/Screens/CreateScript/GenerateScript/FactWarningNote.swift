//
//  FactWarningNote.swift
//  Cue Studio
//

import SwiftUI

/// The fixed warning under the prompt box: models can get facts wrong. It names Private Cloud
/// Compute only while the prompt will really be written with it.
struct FactWarningNote: View {
    let usesPrivateCloudCompute: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Label {
            Group {
                if usesPrivateCloudCompute {
                    Text("AI can get facts wrong. Topics like history or science are written with Apple’s Private Cloud Compute — check dates, names and numbers before you record.")
                } else {
                    Text("AI can get facts wrong. Check dates, names and numbers before you record.")
                }
            }
            .foregroundStyle(Palette.ink.opacity(0.86))
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Palette.warn)
        }
        .font(.footnote)
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.warnWash, in: shape)
        .overlay(shape.strokeBorder(Palette.warnBorder, lineWidth: 0.5))
        .accessibilityIdentifier("generate.factWarning")
    }
}
