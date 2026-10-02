//
//  EditorAccessoryBar.swift
//  Cue Studio
//

import SwiftUI

/// The bar above the keyboard: AI, Cues, Sections and Options (each opens its panel in the
/// keyboard's place) and, at the end, the button that puts the keyboard away or brings it back.
struct EditorAccessoryBar: View {
    let viewModel: ScriptDetailViewModel

    var body: some View {
        HStack(spacing: 4) {
            Button {
                viewModel.toggle(.ai)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold))
                    Text("AI")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accText)
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .frame(height: 36)
                .background(viewModel.tool == .ai ? Palette.accLine : Palette.accSoft, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Improve with AI"))
            .accessibilityAddTraits(viewModel.tool == .ai ? .isSelected : [])
            .accessibilityIdentifier("editor.tool.ai")
            ForEach([EditorTool.cues, .sections, .options]) { tool in
                toolButton(tool)
            }
            Spacer(minLength: 0)
            Button {
                viewModel.toggleKeyboard()
            } label: {
                Image(systemName: viewModel.isInputVisible ? "keyboard.chevron.compact.down" : "keyboard")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(viewModel.isInputVisible ? String(localized: "Hide keyboard") : String(localized: "Show keyboard")))
            .accessibilityIdentifier("editor.keyboardButton")
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(Palette.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.separator).frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.accessoryBar")
    }

    private func toolButton(_ tool: EditorTool) -> some View {
        let isOpen = viewModel.tool == tool
        return Button {
            viewModel.toggle(tool)
        } label: {
            glyph(tool)
                .foregroundStyle(Palette.ink)
                .frame(width: Metrics.hitTarget, height: 36)
                .background(isOpen ? Palette.overlayFill : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tool.label))
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityIdentifier("editor.tool.\(tool.rawValue)")
    }

    @ViewBuilder
    private func glyph(_ tool: EditorTool) -> some View {
        switch tool {
        case .cues:
            // The cue's own brackets: what it adds to the text.
            Text("[ ]").font(.system(size: 17, weight: .medium, design: .monospaced))
        case .sections:
            Image(systemName: "text.alignleft").font(.system(size: 19, weight: .regular))
        case .options:
            Image(systemName: "textformat").font(.system(size: 19, weight: .regular))
        case .ai:
            Image(systemName: "sparkles").font(.system(size: 19, weight: .regular))
        }
    }
}
