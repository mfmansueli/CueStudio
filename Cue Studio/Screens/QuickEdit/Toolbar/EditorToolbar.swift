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
    @State private var tooltip: String?
    @State private var tooltipTask: Task<Void, Never>?
    /// Where the tools are scrolled: whether some wait on the left, and on the right.
    @State private var scrollEdges = ScrollEdges()
    /// The tool at the leading edge, kept and given back by the view model's memory.
    @State private var scrollPosition = ScrollPosition(idType: String.self)

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
        // New tools start from their first one, or where their kind was left (`EditorToolbarScrollMemory`).
        .onChange(of: context) { _, next in
            scrollEdges = ScrollEdges()
            restoreScroll(for: next)
        }
        .onAppear { restoreScroll(for: context) }
        .background(Palette.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.Editor.separator).frame(height: 0.5)
        }
        .overlay(alignment: .top) {
            if let tooltip {
                Text(tooltip)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .toastSurface(in: Capsule())
                    .offset(y: -38)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
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
            let pinned = viewModel.toolbarItems.filter(\.isPinned)
            GeometryReader { proxy in
                let items = viewModel.toolbarItems.filter { !$0.isPinned }
                let separators = CGFloat(items.filter(\.startsGroup).count) * 4.5
                // On an item's bar only its own tools (the first group) narrow to show whole; elsewhere the whole bar, as one.
                let own = context.isItem ? (items.firstIndex(where: \.startsGroup) ?? items.count) : items.count
                let fitted = itemWidths(items, fittingFirst: own, available: proxy.size.width - 8 - (own == items.count ? separators : 0))
                let badge = badgeLayout(items, widths: fitted)
                let widths = badge.widths
                let overflows = widths.reduce(0, +) + 8 + separators > proxy.size.width + 0.5
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 0) {
                                if item.startsGroup {
                                    Rectangle().fill(Palette.Editor.separator).frame(width: 0.5, height: 30).padding(.horizontal, 2)
                                        .accessibilityHidden(true)
                                }
                                itemButton(item, width: widths[index], badge: badge.words)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 4)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollPosition($scrollPosition, anchor: .leading)
                .onChange(of: scrollPosition.viewID(type: String.self)) { _, tool in
                    viewModel.toolbarScroll.scrolled(to: tool, in: context)
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

    private func backButton(_ context: String) -> some View {
        Button(action: viewModel.leaveToolbarContext) {
            VStack(spacing: 4) {
                // Back points where back is: left, and right in Arabic.
                Image(systemName: "chevron.backward")
                    .font(.editorGlyph(EditorGlyph.toolbar, weight: .semibold))
                Text(context)
                    .font(.system(size: heightClass.toolbarLabelSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Palette.accText)
            .frame(width: 58)
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

    /// The room each tool takes, its side padding included (`EditorToolbarFit`): the class's width, a little less when that
    /// lets the first `count` tools show whole.
    private func itemWidths(_ items: [EditorToolbarItem], fittingFirst count: Int, available: CGFloat) -> [CGFloat] {
        let padding: CGFloat = heightClass.toolbarShowsLabels ? 4 : 0
        let font = UIFont.systemFont(ofSize: heightClass.toolbarLabelSize, weight: .medium)
        let labels = items.map { item in
            heightClass.toolbarShowsLabels ? ceil((item.label as NSString).size(withAttributes: [.font: font]).width) : 0
        }
        return EditorToolbarFit.widths(
            labels: labels, fittingFirst: count, preferred: heightClass.toolbarItemWidth + padding,
            minimum: heightClass.toolbarItemMinimumWidth + padding, padding: padding, breathing: padding + 6, available: available
        )
    }

    /// The words of the bar's badges and the tools' widths for them: the long words when every badged tool has room for them,
    /// a little wider if need be (`EditorToolbarFit.longBadgeFits`), else the short one at the widths as they were.
    private func badgeLayout(_ items: [EditorToolbarItem], widths: [CGFloat]) -> (words: String, widths: [CGFloat]) {
        guard let scope = items.lazy.compactMap(\.scopeBadge).first else { return ("", widths) }
        let long = EditorToolbarBadge.long(scope)
        let labelWidth = EditorToolbarBadge.width(of: long)
        let badged = zip(items, widths).filter { $0.0.scopeBadge != nil }.map(\.1)
        let preferred = heightClass.toolbarItemWidth + (heightClass.toolbarShowsLabels ? 4 : 0)
        guard EditorToolbarFit.longBadgeFits(labelWidth: labelWidth, toolWidths: badged, preferred: preferred) else {
            return (EditorToolbarBadge.short(scope), widths)
        }
        let room = EditorToolbarFit.badgeRoom(labelWidth: labelWidth)
        return (long, zip(items, widths).map { item, width in item.scopeBadge == nil ? width : max(width, room) })
    }

    /// Scrolls `context`'s tools to where their kind was left, or to the first.
    private func restoreScroll(for context: EditorToolbarContext) {
        if let tool = viewModel.toolbarScroll.enter(context) {
            scrollPosition.scrollTo(id: tool, anchor: .leading)
        } else {
            scrollPosition.scrollTo(edge: .leading)
        }
    }

    private func itemButton(_ item: EditorToolbarItem, width: CGFloat, badge words: String = "") -> some View {
        let tint: Color = switch item.style {
        case .normal: Palette.ink
        case .dimmed: Palette.ink3
        case .destructive: Palette.dangerText
        case .smart: Palette.aiText
        }
        let labelTint: Color = switch item.style {
        case .normal: Palette.ink2
        case .dimmed: Palette.inkHint
        case .destructive: Palette.dangerText
        case .smart: Palette.aiTextStrong
        }
        return Button {
            viewModel.tap(item)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: item.systemImage)
                    .font(.editorGlyph(EditorGlyph.add, weight: .light))
                    .foregroundStyle(tint)
                    .frame(height: 24)
                    .overlay(alignment: .top) {
                        // Centered over the icon, never wider than the tool: it says the reach, the tool does what it always does.
                        if item.scopeBadge != nil {
                            Text(words)
                                .font(.editorGlyph(EditorGlyph.badge, weight: .heavy))
                                .foregroundStyle(Palette.accInk)
                                .lineLimit(1)
                                .padding(.horizontal, EditorToolbarFit.badgePadding)
                                .padding(.vertical, 1)
                                .background(Palette.acc, in: Capsule())
                                // A ring of the bar's color keeps it apart from the icon under it.
                                .padding(EditorToolbarFit.badgeRing)
                                .background(Palette.bg, in: Capsule())
                                .fixedSize()
                                .alignmentGuide(.top) { $0[.bottom] - 6 }
                                .accessibilityHidden(true)
                        }
                    }
                if heightClass.toolbarShowsLabels {
                    Text(item.label)
                        .font(.system(size: heightClass.toolbarLabelSize, weight: .medium))
                        .foregroundStyle(labelTint)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .frame(minWidth: width - (heightClass.toolbarShowsLabels ? 4 : 0), maxHeight: .infinity)
            .padding(.horizontal, heightClass.toolbarShowsLabels ? 2 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in
            guard !heightClass.toolbarShowsLabels else { return }
            show(tooltip: item.label)
        })
        .accessibilityShowsLargeContentViewer { Label(item.label, systemImage: item.systemImage) }
        .accessibilityLabel(item.scopeBadge == nil ? Text(item.label) : Text("\(item.label), whole video"))
        .accessibilityHint(item.style == .dimmed ? Text("Not available here") : Text(""))
        .accessibilityIdentifier("edit.toolbar.\(item.id)")
    }

    private func show(tooltip label: String) {
        tooltipTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { tooltip = label }
        tooltipTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.15)) { tooltip = nil }
        }
    }
}
