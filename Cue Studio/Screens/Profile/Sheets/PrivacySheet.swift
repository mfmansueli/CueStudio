//
//  PrivacySheet.swift
//  Cue Studio
//

import SwiftUI

/// What Cue does with the creator's data: everything stays on the device.
struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                item(
                    title: "Scripts and takes stay on this iPhone",
                    detail: "Cue has no account and no server. Your scripts, takes and Creator DNA are stored on this device and in your device backups.",
                    systemImage: "iphone"
                )
                item(
                    title: "AI runs on the device",
                    detail: "Drafts and rewrites use Apple Intelligence's on-device model. Your briefs and scripts are never sent anywhere.",
                    systemImage: "cpu"
                )
                item(
                    title: "You decide what leaves",
                    detail: "Videos leave Cue only when you save them to Photos or share them. Camera and microphone are used only while the camera is open.",
                    systemImage: "hand.raised"
                )
                if let url = AppLinks.privacyPolicy {
                    Link("Privacy policy", destination: url)
                }
            }
            .navigationTitle("Privacy & AI data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func item(title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Palette.ink2)
            }
            .padding(.vertical, 4)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(Palette.acc)
        }
    }
}

#if DEBUG
#Preview {
    PrivacySheet()
}
#endif
