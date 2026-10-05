//
//  VoiceAdjustSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Adjust": what didn't sound like the creator, as chips; what would change, in a line each; and
/// whether it is for this script only or kept in the profile. "Rewrite" writes it again.
struct VoiceAdjustSheet: View {
    let onRewrite: ([VoiceAdjustment], _ keepsInProfile: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: [VoiceAdjustment] = []
    @State private var keepsInProfile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(
                title: String(localized: "What didn’t sound like you?"),
                subtitle: String(localized: "Pick what to change. Cue rewrites it.")
            )
            FlowLayout(spacing: 8, lineSpacing: 0) {
                ForEach(VoiceAdjustment.allCases) { adjustment in
                    let on = picked.contains(adjustment)
                    Button { toggle(adjustment) } label: {
                        FilterChip(label: adjustment.label, isSelected: on, height: 40)
                            .fixedSize()
                            .frame(minHeight: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("voiceAdjust.\(adjustment.id)")
                }
            }
            if !picked.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(picked) { adjustment in
                        Text(adjustment.change)
                            .font(CueStudioFont.hud)
                            .tracking(0.4)
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
            Button {
                onRewrite(picked, keepsInProfile)
                dismiss()
            } label: {
                Text("✦ Rewrite")
            }
            .buttonStyle(.cuePrimary(.large))
            .disabled(picked.isEmpty)
            .accessibilityIdentifier("voiceAdjust.rewrite")
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
        .cueSheetChrome()
        .presentationDetents([.medium])
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voiceAdjust.sheet")
    }

    private func toggle(_ adjustment: VoiceAdjustment) {
        if let index = picked.firstIndex(of: adjustment) {
            picked.remove(at: index)
        } else {
            picked.append(adjustment)
        }
    }
}
