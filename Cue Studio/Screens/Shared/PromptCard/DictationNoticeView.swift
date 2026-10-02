//
//  DictationNoticeView.swift
//  Cue Studio
//

import SwiftUI

/// Why dictation didn't start, or stopped by itself, under the idea field: short, and always with
/// the way out (typing works as before; the microphone refused sends the creator to Settings).
struct DictationNoticeView: View {
    let notice: DictationNotice

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(notice.message)
            } icon: {
                Image(systemName: "mic.slash.fill")
                    .foregroundStyle(Palette.ink2)
            }
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            if notice.offersSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { openURL(url) }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ideaCard.dictationNotice")
    }
}

#if DEBUG
#Preview {
    VStack {
        DictationNoticeView(notice: .microphoneDenied)
        DictationNoticeView(notice: .interrupted)
    }
    .padding()
    .background(Palette.bg)
}
#endif
