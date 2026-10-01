//
//  QuickEditViewModel+TextStyle.swift
//  Cue Studio
//

import Foundation

/// Text style: the picked text's words, and its look on an explicit scope (only this text, every
/// text, or every text and the captions); its keyframes and when it starts and ends. Every change
/// is an undo step; typing and a slider's drag are one.
extension QuickEditViewModel {
    /// The scopes Text style offers.
    static let textStyleScopes: [TextStyleScope] = [.selected, .allTexts, .textsAndCaptions]

    /// "This title", "All texts · 3", "+ Captions".
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
        case .allCaptions, .textsAndCaptions: String(localized: "+ Captions")
        }
    }

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

    /// A Font or Color change on the scope: this text (remembered as changed by hand), every text,
    /// or every text and the captions' look. A slider's quick changes are one undo step.
    func restyleText(_ style: TextStyleEdit, key: String? = nil) {
        guard isReady, let id = selectedTextID else { return }
        switch textStyleScope {
        case .selected:
            customizeText(id, style.field, key: key.map { "\($0).\(id)" }) { style.apply(to: &$0) }
        case .allTexts, .allCaptions, .textsAndCaptions:
            let withCaptions = textStyleScope == .textsAndCaptions
            let picked = selectedText
            change(key: key.map { "\($0).all" }) { snapshot in
                for index in snapshot.texts.indices { style.apply(to: &snapshot.texts[index]) }
                guard withCaptions, style.field != .size else { return }
                // The captions take the texts' look the first time, at a caption's size.
                var look = snapshot.captionLook ?? picked.map(Self.captionLook(from:)) ?? TypePreset.cue.look(for: .caption)
                style.apply(to: &look)
                snapshot.captionCollection = nil
                snapshot.captionLook = look
                snapshot.captionPreset = nil
            }
        }
    }

    /// A text's look as the captions' (no taller than a line of five words fits, at their place).
    static func captionLook(from text: TextOverlay) -> TextLook {
        var look = TextLook(of: text)
        look.sizeScale = 1
        look.verticalOffset = 0
        return look
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

    /// The size Text style shows, in points on the design's frame.
    var pickedTextPointSize: Double {
        ((selectedText?.size ?? TextOverlayRole.title.baseSize) / TextOverlayRole.designScale).rounded()
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
