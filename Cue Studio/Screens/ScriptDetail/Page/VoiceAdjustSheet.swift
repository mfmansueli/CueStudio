//
//  VoiceAdjustSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Adjust": what didn't sound like the creator, as chips; what would change, in a line each; and
/// whether it is for this script only or kept in the profile. "Too long" kept in the profile asks what was too long, so the change lands on
/// the field that makes the next scripts long. "Rewrite" writes it again.
struct VoiceAdjustSheet: View {
    let onRewrite: ([VoiceAdjustment], _ keepsInProfile: Bool, _ cause: TooLongCause?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: [VoiceAdjustment] = []
    @State private var keepsInProfile = false
    @State private var cause: TooLongCause?
    @State private var detent: PresentationDetent = .medium

    /// "What was too long?" is asked: "Too long" is picked and kept in the profile.
    private var asksCause: Bool { keepsInProfile && picked.contains(.tooLong) }
    private var shownCause: TooLongCause? { asksCause ? cause : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(
                title: String(localized: "What didn’t sound like you?"),
                subtitle: String(localized: "Cue suggests. You decide.")
            )
            FlowLayout(spacing: 8, lineSpacing: 0) {
                ForEach(VoiceAdjustment.allCases) { adjustment in
                    chip(adjustment.label, isOn: picked.contains(adjustment), identifier: "voiceAdjust.\(adjustment.id)") { toggle(adjustment) }
                }
            }
            if !picked.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(picked) { adjustment in
                        Text(adjustment.change(cause: shownCause))
                            .hudFont()
                            .interfaceTracking(0.4)
                            .foregroundStyle(Palette.ink2)
                    }
                }
            }
            Picker("Apply to", selection: $keepsInProfile) {
                Text("This script only").tag(false)
                Text("Also my profile").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("voiceAdjust.scope")
            if asksCause { causeQuestion }
            Button {
                onRewrite(picked, keepsInProfile, shownCause)
                dismiss()
            } label: {
                Text("✦ Rewrite")
            }
            .buttonStyle(.cuePrimary(.large))
            .disabled(picked.isEmpty || (asksCause && cause == nil))
            .accessibilityIdentifier("voiceAdjust.rewrite")
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
        .cueSheetChrome()
        // The question needs the room: the sheet opens up when it appears.
        .presentationDetents([.medium, .large], selection: $detent)
        .onChange(of: asksCause) { _, asks in
            if asks { detent = .large }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voiceAdjust.sheet")
    }

    /// "What was too long?": one answer.
    private var causeQuestion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What was too long?")
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.ink)
            FlowLayout(spacing: 8, lineSpacing: 0) {
                ForEach(TooLongCause.allCases) { answer in
                    chip(answer.label, isOn: cause == answer, identifier: "voiceAdjust.cause.\(answer.id)") { cause = answer }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voiceAdjust.cause")
    }

    private func chip(_ label: String, isOn: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            FilterChip(label: label, isSelected: isOn, height: 40)
                .fixedSize()
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func toggle(_ adjustment: VoiceAdjustment) {
        if let index = picked.firstIndex(of: adjustment) {
            picked.remove(at: index)
        } else {
            picked.append(adjustment)
        }
    }
}
