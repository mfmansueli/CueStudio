//
//  EditorPanelContainer.swift
//  Cue Studio
//

import SwiftUI

/// Every panel's frame: the title and, under it, what the panel changes ("This clip", "Whole
/// take", "Applies to all 8 lines"); Reset once something changed; ◐ in the panels that change
/// the picture or the sound; and the yellow ✓ that applies and closes. Reset sits left of ◐ and ✓,
/// so they never move when it appears. Under the header, optional fixed rows (a field, tabs), then the content, which scrolls
/// when it doesn't fit (large text, a short screen), and an optional footer that never scrolls away
/// (Pauses' "Remove 3 pauses").
///
/// With `expansion` (the styling panels), a grabber and an expand button in the header make the
/// panel taller and the video smaller; dragging the header up or down does the same. Their content
/// (and Background's, `clearsHomeIndicator`) stops further above the Home Indicator and fades under it while it scrolls.
struct EditorPanelContainer<Fixed: View, Content: View, Footer: View>: View {
    let title: String
    let subtitle: String
    @Environment(\.dynamicTypeSize) private var typeSize
    /// VoiceOver lands on the title when the panel opens, so the controls it brought are read from the top.
    @AccessibilityFocusState private var titleIsFocused: Bool
    var onReset: (() -> Void)?
    /// ◐ Compare with original, between Reset and ✓ (panels that change the picture or the sound).
    var compare: PanelCompare?
    /// "Preview" before expand and ✓: plays what the panel changes on the video (`PanelPlay`).
    var play: PanelPlay?
    /// One more of the panel's own, right before ✓ (Captions' •••: its less used tools, out of the scroll).
    var accessory: AnyView?
    var expansion: Binding<Bool>?
    /// The content stops further above the Home Indicator and fades under it while it scrolls (always with `expansion`).
    var clearsHomeIndicator = false
    /// What the content shows (the panel's tab): when it changes, the content starts again from its top. A tab opened while the
    /// last one was scrolled to its end showed the middle of its own controls, with the first ones out of sight above.
    var contentKey: AnyHashable?
    /// Where the content was scrolled to, kept for when it shows again (Caption style › Styles: back from another tab, the cards
    /// are where they were); nil starts at the top.
    var keptOffset: Binding<CGFloat>?
    /// True while the panel's Advanced is open: as it opens, the content scrolls to put Advanced at the top with its controls under
    /// it, so they show whole without a search (owner, canvas 2: Volume › Advanced reached whole; the panel grows at the same time).
    var revealsAdvanced = false
    let onApply: () -> Void
    @ViewBuilder var fixed: Fixed
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    @State private var position = ScrollPosition(edge: .top)

    private var isRoomy: Bool { expansion != nil || clearsHomeIndicator }

    /// How far the header has to be dragged to expand or collapse the panel.
    private static var dragThreshold: CGFloat { 24 }

    var body: some View {
        VStack(spacing: 0) {
            header
            fixed
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .task(id: revealsAdvanced) {
                guard revealsAdvanced else { return }
                // After the panel has grown and the new controls are laid out: Advanced at the top, its controls under it.
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.smooth) { proxy.scrollTo(PanelAdvancedButton.scrollID, anchor: .top) }
            }
            .scrollPosition($position)
            .onScrollGeometryChange(
                for: CGFloat.self, of: { $0.contentOffset.y + $0.contentInsets.top },
                action: { _, offset in keptOffset?.wrappedValue = max(0, offset) }
            )
            .task(id: contentKey) {
                // After the content is laid out: the offset it was left at, else its top.
                if let kept = keptOffset?.wrappedValue, kept > 0 {
                    position.scrollTo(y: kept)
                } else {
                    position.scrollTo(edge: .top)
                }
            }
            .id(contentKey)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(isRoomy ? .soft : nil, for: .bottom)
            }
            footer
                .padding(.horizontal, 16)
                .padding(.bottom, Footer.self == EmptyView.self ? 0 : 10)
        }
        // The background below runs to the screen's edge; the controls stop above the bottom safe
        // area (the Home Indicator), wherever the panel is shown: under the timeline or in a sheet.
        .safeAreaPadding(.bottom, isRoomy ? Metrics.editorStylePanelBottomClearance : Metrics.editorPanelBottomClearance)
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
        // VoiceOver's escape (a two-finger Z) closes the panel like ✓: its changes are already on the video.
        .accessibilityAction(.escape, onApply)
        .onAppear { titleIsFocused = true }
        // Controls grow up to AX Medium; past it the panel's content scrolls.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// The title and subtitle beside Reset, ◐, ▶, expand and ✓ while the title fits whole on one line there (with room for the
    /// subtitle on up to three); else the buttons on a row of their own and the title and subtitle under them, across the panel.
    /// The title is never cut, in any language (owner, 02/11/2026: no label is ever cut; "Automatiske undertekster" beside five
    /// buttons on an iPhone SE).
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                titles(titleLines: 1)
                    .frame(minWidth: Self.titleMinimumWidth, maxWidth: .infinity, alignment: .leading)
                headerButtons
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    headerButtons
                }
                titles(titleLines: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)
            }
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

    /// The least room the title and subtitle keep beside the buttons: under it the subtitle would need more than three lines.
    private static var titleMinimumWidth: CGFloat { 120 }

    /// The title (on one line beside the buttons, on up to two across the panel) and what the panel changes under it. The
    /// subtitle wraps to the room the title leaves (it never decides the layout: `idealWidth: 0`), on up to three lines.
    private func titles(titleLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(.body, weight: .bold))
                .lineLimit(titleLines)
                .minimumScaleFactor(titleLines == 1 ? 1 : 0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleIsFocused)
            Text(subtitle)
                .font(.system(.footnote))
                .foregroundStyle(Palette.ink2)
                .lineLimit(typeSize.isAccessibilitySize ? 4 : 3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("edit.panel.subtitle")
        }
    }

    /// Reset, ◐, ▶, expand, the panel's own and ✓, in that order: ✓ never moves when Reset appears.
    @ViewBuilder private var headerButtons: some View {
        if let onReset {
            Button("Reset", action: onReset)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .buttonStyle(.plain)
                .accessibilityIdentifier("edit.panel.reset")
        }
        if let compare { PanelCompareButton(compare: compare) }
        if let play { playButton(play) }
        if let expansion { expandButton(expansion) }
        if let accessory { accessory }
        Button {
            Haptics.apply()
            onApply()
        } label: {
            Image(systemName: "checkmark")
                .font(.editorGlyph(EditorGlyph.control, weight: .bold))
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

    /// ▶ as round as expand, with a small "PREVIEW" tag above its corner (as the toolbar's "ALL"), so it never reads as the
    /// video's own play button and takes no more room than the buttons beside it.
    private func playButton(_ play: PanelPlay) -> some View {
        Button {
            Haptics.selection()
            play.action()
        } label: {
            Image(systemName: "play.fill")
                .font(.editorGlyph(EditorGlyph.button, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: Metrics.applyButtonSize, height: Metrics.applyButtonSize)
                .background(Palette.fill, in: Circle())
                .overlay(alignment: .topTrailing) {
                    Text(PanelPlay.tag)
                        .font(.editorGlyph(EditorGlyph.badge, weight: .heavy))
                        .foregroundStyle(Palette.accInk)
                        .lineLimit(1)
                        .padding(.horizontal, EditorToolbarFit.badgePadding)
                        .padding(.vertical, 1)
                        .background(Palette.acc, in: Capsule())
                        .fixedSize()
                        .offset(x: 6, y: -7)
                        .accessibilityHidden(true)
                }
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(PanelPlay.label))
        .accessibilityShowsLargeContentViewer { Label(PanelPlay.label, systemImage: "play.fill") }
        .accessibilityIdentifier(PanelPlay.identifier)
    }

    /// Expand or collapse: arrows out (the panel grows, the video shrinks) or in.
    private func expandButton(_ expansion: Binding<Bool>) -> some View {
        let isExpanded = expansion.wrappedValue
        return Button {
            Haptics.selection()
            expansion.wrappedValue.toggle()
        } label: {
            Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.editorGlyph(EditorGlyph.button, weight: .semibold))
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
