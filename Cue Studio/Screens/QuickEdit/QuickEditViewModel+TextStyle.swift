//
//  QuickEditViewModel+TextStyle.swift
//  Cue Studio
//

import Foundation

/// Text style: the picked text's words, and its look on an explicit scope (only this text, or
/// every text); its keyframes and when it starts and ends, always the picked text's. Every change
/// is an undo step; typing and a slider's drag are one. The captions are styled in Caption style
/// (a text's look reaches them only through "Apply this style to captions").
extension QuickEditViewModel {
    /// The scopes Text style offers.
    static let textStyleScopes: [TextStyleScope] = [.selected, .allTexts]

    /// "This title", "All texts · 3".
    func textStyleScopeLabel(_ scope: TextStyleScope) -> String {
        switch scope {
        case .selected:
            switch selectedText?.role ?? .title {
            case .title: String(localized: "This title")
            case .subtitle: String(localized: "This subtitle")
            case .hook: String(localized: "This hook")
            case .callout: String(localized: "This callout")
            }
        case .allTexts: String(localized: "All texts · \(edit.texts.count)")
        case .allCaptions: String(localized: "Captions")
        }
    }

    /// The tab Text style shows: the one picked, when it is one of Text style's (the tabs and what
    /// shows under them never disagree).
    var textStyleTab: EditorPanelTab {
        EditorPanelTab.textStyle.contains(panelTab) ? panelTab : .presets
    }

    /// Presets, Font and Color change the look, on the scope; Motion is the picked text's.
    var textStyleTabChangesLook: Bool { textStyleTab != .motion }

    /// "Type your title".
    var textFieldPlaceholder: String {
        switch selectedText?.role ?? .title {
        case .title: String(localized: "Type your title")
        case .subtitle: String(localized: "Type your subtitle")
        case .hook: String(localized: "Type your hook")
        case .callout: String(localized: "Type your callout")
        }
    }

    /// New words for a text; typing in a row is one undo step.
    func setTextContent(_ id: UUID, _ content: String) {
        updateText(id, key: "text.\(id)") { $0.text = content }
    }

    /// A Font or Color change on the scope: this text (remembered as changed by hand) or every
    /// text. A slider's quick changes are one undo step. The captions keep their own look.
    func restyleText(_ style: TextStyleEdit, key: String? = nil) {
        guard isReady, let id = selectedTextID else { return }
        switch textStyleScope {
        case .selected:
            customizeText(id, style.field, key: key.map { "\($0).\(id)" }) { style.apply(to: &$0) }
        case .allTexts:
            change(key: key.map { "\($0).all" }) { snapshot in
                for index in snapshot.texts.indices { style.apply(to: &snapshot.texts[index]) }
            }
        case .allCaptions:
            // Not one of Text style's scopes: captions are styled in Caption style.
            return
        }
    }

    /// The preset Text style marks: the picked text's.
    var pickedTextPreset: TypePreset? { selectedText?.preset }

    /// "My style" is marked when the picked text looks exactly like it.
    var pickedTextIsMyStyle: Bool {
        guard let myStyle, let text = selectedText, text.preset == nil else { return false }
        var mine = myStyle
        mine.sizeScale = TextLook(of: text).sizeScale
        mine.verticalOffset = TextLook(of: text).verticalOffset
        return mine == TextLook(of: text)
    }

    /// A preset (or My style, nil) on the scope.
    func pickTextPreset(_ preset: TypePreset?) {
        guard isReady else { return }
        if let preset {
            applyPreset(preset, to: textStyleScope)
        } else {
            applyMyStyle(to: textStyleScope)
        }
    }

    /// The size Text style shows: `TextOverlay.size`, 24–120 pt.
    var pickedTextPointSize: Double {
        (selectedText?.size ?? TextOverlayRole.title.baseSize).rounded()
    }

    // MARK: - Motion

    /// "3 keyframes", "No keyframes yet" (the picked text, or photo or video).
    var keyframeCountLabel: String {
        let count = motionItem.map { keyframes(of: $0).count } ?? 0
        switch count {
        case 0: return String(localized: "No keyframes yet")
        case 1: return String(localized: "1 keyframe")
        default: return String(localized: "\(count) keyframes")
        }
    }

    /// A keyframe sits at the playhead (Remove keyframe instead of Add).
    var hasKeyframeAtPlayhead: Bool {
        motionItem.flatMap(keyframeAtPlayhead(of:)) != nil
    }

    /// Whether there is a keyframe before (or after) the playhead to go to.
    func hasKeyframe(forward: Bool) -> Bool {
        guard let item = motionItem, let span = editedSpan(of: item) else { return false }
        let local = player.currentTime - span.start
        return keyframes(of: item).contains { forward ? $0.time > local + OverlayKeyframe.sameMoment : $0.time < local - OverlayKeyframe.sameMoment }
    }

    /// Starts or Ends −/+: the picked text (or photo or video) a tenth earlier or later.
    func nudgeLayerEdge(_ edge: LayerEdge, by seconds: TimeInterval) {
        guard let bar = selectedLayer, bar.kind == .text || bar.kind == .media else { return }
        resizeBar(bar, edge: edge, to: (edge == .start ? bar.span.start : bar.span.end) + seconds)
    }
}
