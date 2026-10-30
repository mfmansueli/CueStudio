//
//  PrivacySheet.swift
//  Cue Studio
//

import SwiftUI

/// What Cue does with the creator's data: it stays on the device, and the AI is Apple Intelligence (and, where it is offered, AI Scripts Ultra
/// with Google's Gemini, only when the creator allowed it and picked it). Opened from Settings and from the paywall's footer.
struct PrivacySheet: View {
    /// Private Cloud Compute is named only when the app can use it.
    var usesPrivateCloudCompute = ScriptAIService.hasPrivateCloudComputeEntitlement

    @Environment(\.dismiss) private var dismiss
    @Environment(DataEraserService.self) private var eraser
    @Environment(ToastService.self) private var toast
    @Environment(UltraScriptService.self) private var ultra
    @State private var confirmsErase = false

    var body: some View {
        NavigationStack {
            List {
                item(
                    title: "Scripts and takes stay on this iPhone",
                    detail: "Cue has no server. Your scripts, takes and My Cue Voice are stored on this device and in your device backups. Sign in with Apple is optional and only keeps your Apple ID on this iPhone.",
                    systemImage: "iphone"
                )
                if ultra.isAvailable {
                    item(
                        title: "Apple Intelligence, and Ultra AI if you allow it",
                        detail: "Apple Intelligence writes by default. Ultra AI sends your request and voice preferences to Google, which runs its model, only when you allow it and pick it for a script. Writing examples and imported excerpts stay on this iPhone.",
                        systemImage: "cpu"
                    )
                } else {
                    item(
                        title: "Apple Intelligence, nothing else",
                        detail: usesPrivateCloudCompute
                            ? "Apple Intelligence can use this iPhone or Private Cloud Compute. Your request and voice preferences may be sent to Apple. Writing examples and imported excerpts stay on this iPhone."
                            : "Scripts, rewrites, hooks and theme ideas are all written on this iPhone. No other AI service is involved.",
                        systemImage: "cpu"
                    )
                }
                item(
                    title: "You decide what leaves",
                    detail: "Videos leave Cue only when you save them to Photos or share them. Camera and microphone are used only while the camera is open.",
                    systemImage: "hand.raised"
                )
                if let url = AppLinks.privacyPolicy {
                    Link("Privacy policy", destination: url)
                }
                Section {
                    Button("Delete my Cue data", role: .destructive) { confirmsErase = true }
                        .accessibilityIdentifier("privacy.deleteButton")
                } footer: {
                    Text("Removes your scripts, takes, edits and My Cue Voice from this iPhone. Videos saved to Photos stay there.")
                }
            }
            .alert("Delete all your Cue data?", isPresented: $confirmsErase) {
                Button("Delete everything", role: .destructive) {
                    eraser.eraseEverything()
                    toast.show(String(localized: "Your Cue data is deleted"))
                    dismiss()
                }
                .accessibilityIdentifier("privacy.confirmDelete")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your scripts, takes, edits and My Cue Voice are removed from this iPhone. This can't be undone.")
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
                Text(title).cueFont(.headline, weight: .semibold)
                Text(detail).cueFont(.subheadline).foregroundStyle(Palette.ink2)
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
