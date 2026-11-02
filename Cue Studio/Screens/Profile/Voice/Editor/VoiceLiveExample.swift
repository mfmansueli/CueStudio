//
//  VoiceLiveExample.swift
//  Cue Studio
//

import SwiftUI

/// The live example of a choice (the owner's item 1, 02/11/2026): one line of the sample script, changing with each tap and marked as an example.
/// It grows with Dynamic Type, and VoiceOver reads the new line after the choice (item 15).
struct VoiceLiveExample: View {
    let caption: String
    let line: String
    var identifier = "voice.example"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption.uppercased())
                .monoFont(size: 10.5, weight: .bold)
                .interfaceTracking(1)
                .foregroundStyle(Palette.aiText)
            Text("“\(line)”")
                .cueFont(.callout)
                .italic()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: line)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
        .onChange(of: line) { _, new in
            AccessibilityNotification.Announcement(String(localized: "Example: \(new)")).post()
        }
    }
}
