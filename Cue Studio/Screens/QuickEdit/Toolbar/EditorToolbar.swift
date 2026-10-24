//
//  EditorToolbar.swift
//  Cue Studio
//

import SwiftUI

/// The toolbar under the timeline. With something picked (or the Text, Captions or Audio menu
/// open), it swaps its whole content for that context's tools, with a yellow "‹ Clip" back to the
/// main ones. It scrolls sideways, with a fade on each side where more tools wait; Delete,
/// in red, stays at the right end whatever the scroll. On the smallest screens it keeps only the
/// icons; their labels stay for VoiceOver and a long press.
struct EditorToolbar: View {
    let viewModel: QuickEditViewModel
    let heightClass: EditorHeightClass

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The label shown by a long press when labels are hidden.
    @State private var tooltip: String?
    @State private var tooltipTask: Task<Void, Never>?
    /// Where the tools are scrolled: whether some wait on the left, and on the right.
    @State private var scrollEdges = ScrollEdges()

    private struct ScrollEdges: Equatable {
        var hidesLeading = false
        var hidesTrailing = true
    }

    var body: some View {
        let context = viewModel.toolbarContextLabel
        ZStack {
            content(context)
                .id(context)
                .transition(.opacity)
        }
        // A short crossfade when the tools change.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: context)
        // New tools start from their first one.
        .onChange(of: context) { scrollEdges = ScrollEdges() }
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
                    .background(Palette.Editor.toast, in: Capsule())
                    .offset(y: -38)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .disabled(!viewModel.isReady || viewModel.audio.isRecordingVoiceOver)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.toolbar")
    }

    private func content(_ context: String?) -> some View {
        HStack(spacing: 0) {
            if let context {
                backButton(viewModel.toolbarContextName ?? context)
            }
            let pinned = viewModel.toolbarItems.filter(\.isPinned)
            GeometryReader { proxy in
                let items = viewModel.toolbarItems.filter { !$0.isPinned }
                let overflows = CGFloat(items.count) * heightClass.toolbarItemWidth + 8 > proxy.size.width
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(items) { item in
                            if item.startsGroup {
                                Rectangle().fill(Palette.Editor.separator).frame(width: 0.5, height: 30).padding(.horizontal, 2)
                            }
                            itemButton(item)
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(minHeight: proxy.size.height)
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
                itemButton(item)
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

    private func itemButton(_ item: EditorToolbarItem) -> some View {
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
            viewModel.perform(item.action)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: item.systemImage)
                    .font(.editorGlyph(EditorGlyph.add, weight: .light))
                    .foregroundStyle(tint)
                    .frame(height: 24)
                    .overlay(alignment: .topTrailing) {
                        if let badge = item.scopeBadge {
                            Text(badge)
                                .font(.editorGlyph(EditorGlyph.badge, weight: .heavy))
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.accInk)
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 1)
                                .background(Palette.acc, in: Capsule())
                                .fixedSize()
                                .offset(x: 12, y: -6)
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
            .frame(minWidth: heightClass.toolbarItemWidth, maxHeight: .infinity)
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
