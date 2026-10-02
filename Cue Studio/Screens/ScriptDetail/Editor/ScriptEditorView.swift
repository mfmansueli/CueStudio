//
//  ScriptEditorView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Writing mode: the title, the text as blocks and one bar above the keyboard, nothing else. The
/// rest opens when asked, in the keyboard's place: AI, cues, sections and the script's options.
struct ScriptEditorView: View {
    @Bindable var viewModel: ScriptDetailViewModel

    @AppStorage(DefaultsKey.scriptEditorTextSize) private var textSizeValue = ScriptTextSize.medium.rawValue
    /// What the keyboard measured last, so a panel is as tall as it and nothing jumps.
    @State private var keyboardHeight: CGFloat = 336
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var textSize: Binding<ScriptTextSize> {
        Binding(
            get: { ScriptTextSize(rawValue: textSizeValue) ?? .medium },
            set: { textSizeValue = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScriptEditorHeader(viewModel: viewModel)
            ScriptBlockEditor(viewModel: viewModel, size: textSize.wrappedValue)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                EditorAccessoryBar(viewModel: viewModel)
                if let tool = viewModel.tool {
                    EditorToolPanel(viewModel: viewModel, textSize: textSize, tool: tool, height: panelHeight)
                }
            }
            .background(alignment: .bottom) {
                // Under the home indicator too, in the color of what is above it.
                (viewModel.tool == nil ? Palette.surface : Palette.editorPanel).ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: viewModel.tool)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect, frame.height > 100 else { return }
            keyboardHeight = frame.height
        }
    }

    /// As tall as the keyboard, less the home indicator's room, which the bar's inset already keeps.
    private var panelHeight: CGFloat {
        max(240, keyboardHeight - Self.homeIndicatorInset)
    }

    private static var homeIndicatorInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
    }
}
