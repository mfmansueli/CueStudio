//
//  PrivacySheet.swift
//  Cue Studio
//

import SwiftUI

/// What Cue does with the creator's data: it stays on the device, and the only AI is Apple
/// Intelligence. Opened from Settings and from the paywall's footer.
struct PrivacySheet: View {
    /// Private Cloud Compute is named only when the app can use it.
    var usesPrivateCloudCompute = ScriptAIService.hasPrivateCloudComputeEntitlement

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                item(
                    title: "Scripts and takes stay on this iPhone",
                    detail: "Cue has no server. Your scripts, takes and My Cue Voice are stored on this device and in your device backups. Sign in with Apple is optional and only keeps your Apple ID on this iPhone.",
                    systemImage: "iphone"
                )
                item(
                    title: "Apple Intelligence, nothing else",
                    detail: usesPrivateCloudCompute
                        ? "Rewrites, hooks and theme ideas run on the device. A free-form Prompt is written with Apple's Private Cloud Compute, which uses your request only to answer it and doesn't keep it. No other AI service is involved."
                        : "Scripts, rewrites, hooks and theme ideas are all written on this iPhone. No other AI service is involved.",
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
            Image(systemName: systemImage).foregroundStyle(Palette.accText)
        }
    }
}

#if DEBUG
#Preview {
    PrivacySheet()
}
#endif
