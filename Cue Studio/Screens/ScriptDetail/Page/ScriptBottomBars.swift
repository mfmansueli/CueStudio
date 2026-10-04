//
//  ScriptBottomBars.swift
//  Cue Studio
//

import SwiftUI

/// The page's one Record button: "● Record" (or "● Retake" once there is a take), the screen's yellow fill, except on a recorded
/// script that hasn't changed since its take, which stays quiet.
struct ScriptRecordBar: View {
    let title: LocalizedStringKey
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().fill(Palette.record).frame(width: 11, height: 11)
                Text(title).font(.system(size: 17, weight: .bold))
            }
        }
        .buttonStyle(CueStudioButtonStyle(variant: isPrimary ? .primary : .secondary, size: .large, expands: true))
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("detail.recordButton")
    }
}

/// The cues above the keyboard (v29 · 4.2): pause, smile, emphasis, look at camera. A tap puts the cue where the caret is.
struct ScriptCuesBar: View {
    let onCue: (ScriptCue) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Cues")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Palette.inkHint)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ScriptCue.bar) { cue in
                        Button { onCue(cue) } label: {
                            Text(cue.name)
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Palette.accText)
                                .padding(.horizontal, 13)
                                .frame(height: 34)
                                .background(Palette.accSoft, in: Capsule())
                                .frame(minHeight: Metrics.hitTarget)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Cue \(cue.name)"))
                        .accessibilityIdentifier("page.cue.\(String(describing: cue))")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 12)
        .background(Palette.surface)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
        .accessibilityIdentifier("page.cuesBar")
    }
}
