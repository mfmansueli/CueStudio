//
//  PrivacySheet.swift
//  Cue Studio
//

import SwiftUI

/// What Cue does with the creator's data: what they make stays on the device, Cue's server keeps only counts under a random id, usage data and
/// crash reports go to Google only with "Help improve Cue" on, and the AI is Apple Intelligence (and, where it is offered, Ultra AI with
/// Anthropic, only when the creator allowed it and picked it). Opened from Settings and from the paywall's footer.
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
                    detail: String(localized: "Your scripts, takes and My Cue Voice are kept on this iPhone and in its backups. Cue’s server keeps only counts, under a random ID. Usage data and crash reports go to Google only with Help improve Cue on."),
                    systemImage: "iphone"
                )
                if ultra.isAvailable {
                    item(
                        title: "Apple Intelligence, and Ultra AI if you allow it",
                        detail: AIDisclosure.ultraPrivacy,
                        systemImage: "cpu"
                    )
                } else {
                    item(
                        title: "Apple Intelligence, nothing else",
                        detail: usesPrivateCloudCompute
                            ? AIDisclosure.privateCloud
                            : String(localized: "Scripts, rewrites, hooks and theme ideas are all written on this iPhone. No other AI service is involved."),
                        systemImage: "cpu"
                    )
                }
                item(
                    title: "You decide what leaves",
                    detail: String(localized: "Videos leave Cue only when you save them to Photos or share them. Camera and microphone are used only while the camera is open."),
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
            // The one confirmation for erasing everything, the same as Settings' (`confirmsDataErase`): the action sheet at the bottom.
            .cueActionSheet(
                isPresented: $confirmsErase,
                message: "Deletes your scripts, takes, edits and My Cue Voice from this iPhone. This can't be undone.",
                note: ultra.isAvailable ? "Already sent can’t be called back: Anthropic keeps Ultra AI requests up to 30 days to detect abuse, never for training. Cue’s server keeps only counts, under a random ID." : nil,
                actionTitle: "Delete my Cue data", actionIdentifier: "privacy.confirmDelete"
            ) {
                eraser.eraseEverything()
                toast.show(String(localized: "Your Cue data is deleted"))
                dismiss()
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

    private func item(title: LocalizedStringKey, detail: String, systemImage: String) -> some View {
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
