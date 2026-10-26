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
    @ViewBuilder var fixed: Fixed
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        EditorPanelContainer(
            title: viewModel.panelTitle(panel), subtitle: viewModel.panelSubtitle(panel), onReset: onReset ?? viewModel.panelReset(panel),
            compare: compare,
            expansion: panel.isExpandable ? expansion : nil, clearsHomeIndicator: panel.scrollsClearOfHomeIndicator, contentKey: viewModel.panelTab,
            keptOffset: keptOffset, onApply: viewModel.closePanel, fixed: { keepTheirOwn; fixed }, content: { content }, footer: { footer }
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

    private var expansion: Binding<Bool> {
        Binding(get: { viewModel.stylePanelIsExpanded }, set: { viewModel.stylePanelIsExpanded = $0 })
    }
}

extension PanelFrame where Fixed == EmptyView, Footer == EmptyView {
    init(
        viewModel: QuickEditViewModel, panel: EditorPanel, onReset: (() -> Void)? = nil, compare: PanelCompare? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            viewModel: viewModel, panel: panel, onReset: onReset, compare: compare, fixed: { EmptyView() }, content: content,
            footer: { EmptyView() }
        )
    }
}

extension PanelFrame where Footer == EmptyView {
    init(
        viewModel: QuickEditViewModel, panel: EditorPanel, onReset: (() -> Void)? = nil, compare: PanelCompare? = nil,
        keptOffset: Binding<CGFloat>? = nil, @ViewBuilder fixed: () -> Fixed, @ViewBuilder content: () -> Content
    ) {
        self.init(
            viewModel: viewModel, panel: panel, onReset: onReset, compare: compare, keptOffset: keptOffset, fixed: fixed, content: content,
            footer: { EmptyView() }
        )
    }
}

extension PanelFrame where Fixed == EmptyView {
    init(
        viewModel: QuickEditViewModel, panel: EditorPanel, onReset: (() -> Void)? = nil, compare: PanelCompare? = nil,
        @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            viewModel: viewModel, panel: panel, onReset: onReset, compare: compare, fixed: { EmptyView() }, content: content, footer: footer
        )
    }
}
