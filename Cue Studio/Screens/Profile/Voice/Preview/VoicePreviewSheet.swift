//
//  VoicePreviewSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Does this sound like you?" (My Cue Voice · screens 1 and 5): the same sample script written two ways, **My voice** and **Without**, as HOOK, BODY and
/// CTA, with tags for what shaped it. **Adjust** swaps this sheet for the tone editor and back; **Sounds like me** counts as an approval, closes and says
/// "Learned from this script". Written on this iPhone; nothing leaves it.
struct VoicePreviewSheet: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast
    @Environment(\.dismiss) private var dismiss

    @State private var showsMine = true
    @State private var isAdjusting = false

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isAdjusting { adjusting } else { preview }
                }
                .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 32, trailing: Metrics.gutter))
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { if isAdjusting { isAdjusting = false } else { dismiss() } }
                        .buttonStyle(.glassProminent)
                        .tint(Palette.acc)
                        .foregroundStyle(Palette.accInk)
                        .accessibilityIdentifier("voice.preview.done")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .cueSheetSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice.preview")
    }

    // MARK: - The preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(eyebrow: eyebrow, title: String(localized: "Does this sound like you?"))
            Picker("", selection: $showsMine) {
                Text("My voice").tag(true)
                Text("Without").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("voice.preview.picker")
            sampleCard
            if showsMine { tags }
            HStack(spacing: 8) {
                Button { isAdjusting = true } label: { Text("Adjust") }
                    .buttonStyle(.cueSecondary(.large))
                    .accessibilityIdentifier("voice.preview.adjust")
                Button(action: soundsLikeMe) { Text("Sounds like me") }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier("voice.preview.soundsLikeMe")
            }
            Text("Written on this iPhone with Apple Intelligence. Nothing leaves your device.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
    }

    private var sample: VoiceSample { showsMine ? VoiceSampleBuilder.sample(for: current) : VoiceSampleBuilder.plain() }

    /// "✦ IN YOUR VOICE · TIKTOK · ~45S", or that the voice is off.
    private var eyebrow: String {
        let state = profile.writesInMyVoice ? String(localized: "in your voice") : String(localized: "My Cue Voice is off")
        let platform = (current.reach.platforms.first ?? current.defaultPlatform).label
        return "✦ \(state) · \(platform) · ~\(seconds)"
    }

    /// About how long the sample runs, from how long their videos usually are.
    private var seconds: String {
        switch current.reach.length {
        case .under30?: String(localized: "25s")
        case .oneToThree?: String(localized: "2m")
        case .longer?: String(localized: "5m")
        case .thirtyToSixty?, nil: String(localized: "45s")
        }
    }

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            part(String(localized: "HOOK"), sample.hook, isFirst: true)
            part(String(localized: "BODY"), sample.body, isFirst: false)
            part(String(localized: "CTA"), sample.cta, isFirst: false)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 14, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(showsMine ? Palette.aiFill : Palette.surface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(showsMine ? Palette.aiBorder : Palette.glassBorder.opacity(0.4), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("voice.preview.card")
    }

    @ViewBuilder
    private func part(_ label: String, _ text: String, isFirst: Bool) -> some View {
        if !text.isEmpty {
            Text(label)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(isFirst ? Palette.accText : Palette.inkHint)
            Text(text)
                .font(.system(size: isFirst ? 17 : 15, weight: isFirst ? .semibold : .regular))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tags: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(sample.tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.aiText)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Palette.aiFill, in: Capsule())
            }
        }
    }

    // MARK: - Adjusting

    /// The tone editor, in this sheet: how they talk, then Done goes back to the preview with what changed.
    private var adjusting: some View {
        VStack(alignment: .leading, spacing: 20) {
            header(eyebrow: VoiceEditorField.tone.eyebrow(for: current), title: VoiceEditorField.tone.title)
            VoiceToneField()
        }
    }

    private func header(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Palette.aiText)
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.56)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Sounds like me

    /// The creator says the sample is them: it counts as an approval (two make an example), the sheet closes and a toast says Cue learned.
    private func soundsLikeMe() {
        profile.profile.approvals += 1
        Haptics.success()
        toast.show(String(localized: "Learned from this script"))
        dismiss()
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) { VoicePreviewSheet() }
        .previewEnvironment()
}
#endif
