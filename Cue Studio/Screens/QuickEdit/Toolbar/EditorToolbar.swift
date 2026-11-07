//
//  EditorToolbar.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The toolbar under the timeline. With something picked (or the Text, Captions or Audio menu
/// open), it swaps its whole content for that context's tools, with a yellow "‹ Clip" back to the
/// main ones. It scrolls sideways, with a fade on each side where more tools wait; Delete,
/// in red, stays at the right end whatever the scroll. A picked item's own tools that would only just overflow draw a
/// little narrower so each shows whole (`EditorToolbarFit`); the editor's other tools wait after them. Where the tools were
/// scrolled is remembered (`EditorToolbarScrollMemory`): the main tools come back where they were left. On the smallest
/// screens it keeps only the icons; their labels stay for VoiceOver and a long press.
struct EditorToolbar: View {
    let viewModel: QuickEditViewModel
    let heightClass: EditorHeightClass

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The label shown by a long press when labels are hidden.
    /// Where the tools are scrolled: whether some wait on the left, and on the right.
    @State private var scrollEdges = ScrollEdges()

    private struct ScrollEdges: Equatable {
        var hidesLeading = false
        var hidesTrailing = true
    }

    var body: some View {
        let context = viewModel.toolbarContext
        ZStack {
            content(context)
                .id(context)
                .transition(.opacity)
        }
        // A short crossfade when the tools change.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: context)
        .onChange(of: context) { scrollEdges = ScrollEdges() }
        .background(Palette.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.Editor.separator).frame(height: 0.5)
        }
        .disabled(!viewModel.isReady || viewModel.audio.isRecordingVoiceOver)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.toolbar")
    }

    private func content(_ context: EditorToolbarContext) -> some View {
        HStack(spacing: 0) {
            if context != .main {
                backButton(viewModel.toolbarContextName ?? "")
            }
            // Built once a drawing: each item asks for its words and state.
            let all = viewModel.toolbarItems
            let pinned = all.filter(\.isPinned)
            GeometryReader { proxy in
                let items = all.filter { !$0.isPinned }
                let separators = CGFloat(items.filter(\.startsGroup).count) * 4.5
                // On an item's bar only its own tools (the first group) narrow to show whole; elsewhere the whole bar, as one.
                let own = context.isItem ? (items.firstIndex(where: \.startsGroup) ?? items.count) : items.count
                let widths = itemWidths(items, fittingFirst: own, available: proxy.size.width - 8 - (own == items.count ? separators : 0))
                let overflows = widths.reduce(0, +) + 8 + separators > proxy.size.width + 0.5
                ScrollViewReader { reader in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 0) {
                                    if item.startsGroup {
                                        Rectangle().fill(Palette.Editor.separator).frame(width: 0.5, height: 30).padding(.horizontal, 2)
                                            .accessibilityHidden(true)
                                    }
                                    itemButton(item, width: widths[index])
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 4)
                        .frame(minHeight: proxy.size.height)
                    }
                    // New tools start from their first one, or where their kind was left (`EditorToolbarScrollMemory`): given back
                    // once as they show, then only followed, so the creator's own scrolling is never pulled back.
                    .onAppear {
                        if let tool = viewModel.toolbarScroll.enter(context) { reader.scrollTo(tool, anchor: .leading) }
                    }
                    .onScrollTargetVisibilityChange(idType: String.self) { visible in
                        // The tools fading out after a change of context say nothing.
                        guard context == viewModel.toolbarContext else { return }
                        viewModel.toolbarScroll.scrolled(to: items.first { visible.contains($0.id) }?.id, in: context)
                    }
                    .scrollIndicators(.hidden)
                    .onScrollGeometryChange(for: ScrollEdges.self) { geometry in
                        ScrollEdges(
                            hidesLeading: geometry.contentOffset.x > 4,
                            hidesTrailing: geometry.contentOffset.x + geometry.containerSize.width < geometry.contentSize.width - 4
                        )
                    } action: { _, edges in
                        scrollEdges = edges
                    }
                    .mask {
                        // A fade on the side where more tools wait, and only there: at the end of the row the last tool shows whole.
                        LinearGradient(
                            stops: [
                                .init(color: overflows && scrollEdges.hidesLeading ? .clear : .black, location: 0),
                                .init(color: .black, location: overflows && scrollEdges.hidesLeading ? 0.1 : 0),
                                .init(color: .black, location: overflows && scrollEdges.hidesTrailing ? 0.84 : 1),
                                .init(color: overflows && scrollEdges.hidesTrailing ? .clear : .black, location: 1),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    }
                }
            }
            ForEach(pinned) { item in
                itemButton(item, width: itemWidths([item], fittingFirst: 1, available: .infinity)[0])
                    .padding(.horizontal, 4)
                    // The tools that scroll away fade out under it.
                    .background(
                        LinearGradient(colors: [Palette.bg.opacity(0), Palette.bg], startPoint: .leading, endPoint: .init(x: 0.3, y: 0.5))
                    )
            }
        }
    }

    /// "‹ Blur area": the name of what the tools change, whole in every language (owner, 02/11/2026: no label is ever cut). It goes
    /// on two lines between words ("Voce fuori / campo"), and the button grows a little for a name that still doesn't fit
    /// (`backWidth`), shrinking it only past that ("Unschärfebereich").
    private func backButton(_ context: String) -> some View {
        Button(action: viewModel.leaveToolbarContext) {
            VStack(spacing: 4) {
                // Back points where back is: left, and right in Arabic.
                Image(systemName: "chevron.backward")
                    .font(.editorGlyph(EditorGlyph.toolbar, weight: .semibold))
                WholeWordsLabel(text: context)
                    .font(.system(size: heightClass.toolbarLabelSize, weight: .semibold))
            }
            .foregroundStyle(Palette.accText)
            .padding(.horizontal, Self.backLabelInset)
            .frame(width: backWidth(context))
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.Editor.separator).frame(width: 0.5)
        }
        // A fixed-height bar: with the largest text sizes a long press shows the label large, as the system's tab bars do.
        .accessibilityShowsLargeContentViewer { Label(context, systemImage: "chevron.backward") }
        .accessibilityLabel(Text("Back to all tools"))
        .accessibilityValue(Text(context))
        .accessibilityIdentifier("edit.toolbar.back")
    }

    /// The back button's width: 58 pt, or as wide as its name needs on one line or on two (`LabelLineBreak`), up to
    /// `backMaximumWidth`, so the tools keep most of the bar.
    private func backWidth(_ context: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: heightClass.toolbarLabelSize, weight: .semibold)
        let width: (String) -> CGFloat = { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) }
        let oneLine = width(context)
        let twoLines = LabelLineBreak.twoLines(context).map { $0.components(separatedBy: "\n").map(width).max() ?? oneLine }
        let needed = min(oneLine, twoLines ?? oneLine) + 2 * Self.backLabelInset
        return min(Self.backMaximumWidth, max(Self.backMinimumWidth, needed))
    }

    private static let backMinimumWidth: CGFloat = 58
    private static let backMaximumWidth: CGFloat = 80
    private static let backLabelInset: CGFloat = 3

    /// The room each tool takes, its side padding included (`EditorToolbarFit`): the class's width, a little less when that
    /// lets the first `count` tools show whole.
    private func itemWidths(_ items: [EditorToolbarItem], fittingFirst count: Int, available: CGFloat) -> [CGFloat] {
        let padding: CGFloat = 4
        let font = UIFont.systemFont(ofSize: heightClass.toolbarLabelSize, weight: .medium)
        let labels = items.map { item in
            ceil((item.label as NSString).size(withAttributes: [.font: font]).width)
        }
        return EditorToolbarFit.widths(
            labels: labels, fittingFirst: count, preferred: heightClass.toolbarItemWidth + padding,
            minimum: heightClass.toolbarItemMinimumWidth + padding, padding: padding, breathing: padding + 6, available: available
        )
    }

    private func itemButton(_ item: EditorToolbarItem, width: CGFloat) -> some View {
        let tint: Color = switch item.style {
        case .normal: Palette.ink
        case .dimmed: Palette.ink3
        case .destructive: Palette.dangerText
        }
        let labelTint: Color = switch item.style {
        case .normal: Palette.ink2
        case .dimmed: Palette.ink2
        case .destructive: Palette.dangerText
        }
        // A switch that is on is lit as the panels' ◐ is: the icon on the accent, its name in the accent's text colour.
        let isLit = item.isOn == true
        return Button {
            viewModel.tap(item)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: item.systemImage)
                    .font(.editorGlyph(EditorGlyph.add, weight: .light))
                    .foregroundStyle(isLit ? Palette.accInk : tint)
                    .frame(height: 24)
                    .background {
                        if isLit {
                            RoundedRectangle(cornerRadius: Metrics.editorInsetRadius, style: .continuous).fill(Palette.acc).frame(width: 40, height: 30)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        // Above the icon's corner, clear of the icon (the bar has room above it at every height): it says the
                        // reach, the tool does what it always does.
                        if let badge = item.scopeBadge {
                            Text(EditorToolbarBadge.words(badge))
                                .font(.editorGlyph(EditorGlyph.badge, weight: .heavy))
                                .foregroundStyle(Palette.accInk)
                                .lineLimit(1)
                                .padding(.horizontal, EditorToolbarFit.badgePadding)
                                .padding(.vertical, 1)
                                .background(Palette.acc, in: Capsule())
                                .fixedSize()
                                .offset(x: 12, y: -10)
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        // It changed the picked clip (canvas 2 M2): a dot low on the icon's corner, never where All sits.
                        if item.isApplied {
                            Circle()
                                .fill(Palette.acc)
                                .frame(width: 6, height: 6)
                                .offset(x: 7, y: 1)
                                .accessibilityHidden(true)
                        }
                    }
                Text(item.label)
                    .font(.system(size: heightClass.toolbarLabelSize, weight: .medium))
                    .foregroundStyle(isLit ? Palette.accText : labelTint)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: width - 4, maxHeight: .infinity)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer { Label(item.label, systemImage: item.systemImage) }
        .accessibilityLabel(item.scopeBadge == nil ? Text(item.label) : Text("\(item.label), whole video"))
        .accessibilityHint(item.style == .dimmed ? Text("Not available here") : Text(""))
        .accessibilityValue(item.isOn.map { $0 ? Text("On") : Text("Off") } ?? (item.isApplied ? Text("Changed on this clip") : Text("")))
        .accessibilityAddTraits(item.isOn == nil ? [] : .isToggle)
        .accessibilityIdentifier("edit.toolbar.\(item.id)")
    }

}
