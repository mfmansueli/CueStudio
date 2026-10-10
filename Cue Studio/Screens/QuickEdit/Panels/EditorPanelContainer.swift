//
//  EditorPanelContainer.swift
//  Cue Studio
//

import SwiftUI

/// Every panel's frame: the title and, under it, what the panel changes ("This clip", "Whole
/// take", "Applies to all 8 lines"); Reset when it makes sense; and the yellow ✓ that applies and
/// closes. Under the header, optional fixed rows (a field, tabs), then the content, which scrolls
/// when it doesn't fit (large text, a short screen), and an optional footer that never scrolls away
/// (Pauses' "Remove 3 pauses").
///
/// With `expansion` (the styling panels), a grabber and an expand button in the header make the
/// panel taller and the video smaller; dragging the header up or down does the same. Their content
/// stops further above the Home Indicator and fades under it while it scrolls.
struct EditorPanelContainer<Fixed: View, Content: View, Footer: View>: View {
    let title: String
    let subtitle: String
    var onReset: (() -> Void)?
    var expansion: Binding<Bool>?
    /// What the content shows (the panel's tab): when it changes, the content starts again from its top. A tab opened while the
    /// last one was scrolled to its end showed the middle of its own controls, with the first ones out of sight above.
    var contentKey: AnyHashable?
    let onApply: () -> Void
    @ViewBuilder var fixed: Fixed
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    /// How far the header has to be dragged to expand or collapse the panel.
    private static var dragThreshold: CGFloat { 24 }

    var body: some View {
        VStack(spacing: 0) {
            header
            fixed
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(contentKey)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(expansion == nil ? nil : .soft, for: .bottom)
            footer
                .padding(.horizontal, 16)
                .padding(.bottom, Footer.self == EmptyView.self ? 0 : 10)
        }
        // The background below runs to the screen's edge; the controls stop above the bottom safe
        // area (the Home Indicator), wherever the panel is shown: under the timeline or in a sheet.
        .safeAreaPadding(.bottom, expansion == nil ? Metrics.editorPanelBottomClearance : Metrics.editorStylePanelBottomClearance)
        .background(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: Metrics.editorPanelRadius, topTrailingRadius: Metrics.editorPanelRadius, style: .continuous)
                .fill(Palette.Editor.panel)
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: Metrics.editorPanelRadius, topTrailingRadius: Metrics.editorPanelRadius, style: .continuous)
                        .strokeBorder(Palette.Editor.separator, lineWidth: 0.5)
                        .mask(alignment: .top) { Rectangle().frame(height: Metrics.editorPanelRadius + 1) }
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
        // Controls grow up to AX Medium; past it the panel's content scrolls.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var header: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.body, weight: .bold))
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(.footnote))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityIdentifier("edit.panel.subtitle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onReset {
                Button("Reset", action: onReset)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("edit.panel.reset")
            }
            if let expansion { expandButton(expansion) }
            Button {
                Haptics.apply()
                onApply()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.accInk)
                    .frame(width: Metrics.applyButtonSize, height: Metrics.applyButtonSize)
                    .background(Palette.acc, in: Circle())
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Apply"))
            .accessibilityIdentifier("edit.panel.apply")
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .padding(.top, expansion == nil ? 0 : 6)
        .frame(minHeight: 56)
        .overlay(alignment: .top) {
            if expansion != nil {
                Capsule()
                    .fill(Palette.ink3)
                    .frame(width: Metrics.editorPanelGrabber.width, height: Metrics.editorPanelGrabber.height)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .gesture(expansionDrag, isEnabled: expansion != nil)
    }

    /// Expand or collapse: arrows out (the panel grows, the video shrinks) or in.
    private func expandButton(_ expansion: Binding<Bool>) -> some View {
        let isExpanded = expansion.wrappedValue
        return Button {
            Haptics.selection()
            expansion.wrappedValue.toggle()
        } label: {
            Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: Metrics.applyButtonSize, height: Metrics.applyButtonSize)
                .background(Palette.fill, in: Circle())
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isExpanded ? "Collapse panel" : "Expand panel"))
        .accessibilityHint(Text(isExpanded ? "Shows the video larger" : "Gives the controls more room"))
        .accessibilityIdentifier("edit.panel.expand")
    }

    /// Up expands, down collapses: the panel follows the finger's direction, like a sheet's grabber.
    private var expansionDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                guard let expansion else { return }
                let height = value.translation.height
                if height < -Self.dragThreshold, !expansion.wrappedValue {
                    Haptics.selection()
                    expansion.wrappedValue = true
                } else if height > Self.dragThreshold, expansion.wrappedValue {
                    Haptics.selection()
                    expansion.wrappedValue = false
                }
            }
    }
}

extension EditorPanelContainer where Fixed == EmptyView, Footer == EmptyView {
    init(title: String, subtitle: String, onReset: (() -> Void)? = nil, onApply: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, onReset: onReset, onApply: onApply, fixed: { EmptyView() }, content: content, footer: { EmptyView() })
    }
}
