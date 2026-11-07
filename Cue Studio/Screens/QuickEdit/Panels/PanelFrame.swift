//
//  PanelFrame.swift
//  Cue Studio
//

import SwiftUI

/// A panel's frame with its title and subtitle from the view model, ✓ closing it. The styling
/// panels expand (`QuickEditViewModel.stylePanelIsExpanded`).
struct PanelFrame<Fixed: View, Content: View, Footer: View>: View {
    let viewModel: QuickEditViewModel
    let panel: EditorPanel
    var onReset: (() -> Void)?
    var compare: PanelCompare?
    /// Where the content is kept scrolled to between tabs (`EditorPanelContainer.keptOffset`).
    var keptOffset: Binding<CGFloat>?
    /// "Preview" in the header (`PanelPlay`).
    var play: PanelPlay?
    /// The panel's own button before ✓ (`EditorPanelContainer.accessory`).
    var accessory: AnyView?
    /// A choice in the subtitle's place (`EditorPanelContainer.subtitleChoice`).
    var subtitleChoice: AnyView?
    @ViewBuilder var fixed: Fixed
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        EditorPanelContainer(
            title: viewModel.panelTitle(panel), subtitle: viewModel.panelSubtitle(panel), subtitleChoice: subtitleChoice,
            onReset: onReset ?? viewModel.panelReset(panel),
            compare: compare, play: play, accessory: accessory,
            expansion: panel.isExpandable ? expansion : nil, clearsHomeIndicator: panel.scrollsClearOfHomeIndicator, contentKey: viewModel.panelTab,
            keptOffset: keptOffset, revealsAdvanced: viewModel.showsAdvanced,
            onApply: viewModel.closePanel, fixed: { keepTheirOwn; fixed }, content: { content }, footer: { footer }
        )
        .accessibilityIdentifier("edit.panel.\(panel.rawValue)")
    }

    /// The whole video's look panels: the clips that keep their own, and "Use this on all".
    @ViewBuilder private var keepTheirOwn: some View {
        let count = panel.hasClipScope ? viewModel.look.clipsKeepingTheirOwnInPanel : 0
        if count > 0 {
            KeepTheirOwnRow(count: count, onUseOnAll: viewModel.look.useWholeVideosLookOnAllClips)
        }
    }

    /// Clean up keeps its own height; the styling panels share theirs.
    private var expansion: Binding<Bool> {
        guard panel == .pauses else {
            return Binding(get: { viewModel.stylePanelIsExpanded }, set: { viewModel.stylePanelIsExpanded = $0 })
        }
        return Binding(get: { viewModel.clips.cleanUpIsExpanded }, set: { viewModel.clips.cleanUpIsExpanded = $0 })
    }
}

extension PanelFrame where Fixed == EmptyView, Footer == EmptyView {
    init(
        viewModel: QuickEditViewModel, panel: EditorPanel, onReset: (() -> Void)? = nil, compare: PanelCompare? = nil,
        play: PanelPlay? = nil, @ViewBuilder content: () -> Content
    ) {
        self.init(
            viewModel: viewModel, panel: panel, onReset: onReset, compare: compare, play: play, fixed: { EmptyView() }, content: content,
            footer: { EmptyView() }
        )
    }
}

extension PanelFrame where Footer == EmptyView {
    init(
        viewModel: QuickEditViewModel, panel: EditorPanel, onReset: (() -> Void)? = nil, compare: PanelCompare? = nil,
        keptOffset: Binding<CGFloat>? = nil, play: PanelPlay? = nil, subtitleChoice: AnyView? = nil, @ViewBuilder fixed: () -> Fixed,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            viewModel: viewModel, panel: panel, onReset: onReset, compare: compare, keptOffset: keptOffset, play: play,
            subtitleChoice: subtitleChoice, fixed: fixed, content: content, footer: { EmptyView() }
        )
    }
}

extension PanelFrame where Fixed == EmptyView {
    init(
        viewModel: QuickEditViewModel, panel: EditorPanel, onReset: (() -> Void)? = nil, compare: PanelCompare? = nil,
        play: PanelPlay? = nil, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            viewModel: viewModel, panel: panel, onReset: onReset, compare: compare, play: play, fixed: { EmptyView() }, content: content,
            footer: footer
        )
    }
}
