//
//  PanelFrame.swift
//  Cue Studio
//

import SwiftUI

/// A panel's frame with its title and subtitle from the view model, ✓ closing it.
struct PanelFrame<Fixed: View, Content: View, Footer: View>: View {
    let viewModel: QuickEditViewModel
    let panel: EditorPanel
    var onReset: (() -> Void)?
    @ViewBuilder var fixed: Fixed
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        EditorPanelContainer(
            title: viewModel.panelTitle(panel), subtitle: viewModel.panelSubtitle(panel), onReset: onReset,
            onApply: viewModel.closePanel, fixed: { fixed }, content: { content }, footer: { footer }
        )
        .accessibilityIdentifier("edit.panel.\(panel.rawValue)")
    }
}

extension PanelFrame where Fixed == EmptyView, Footer == EmptyView {
    init(viewModel: QuickEditViewModel, panel: EditorPanel, onReset: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.init(viewModel: viewModel, panel: panel, onReset: onReset, fixed: { EmptyView() }, content: content, footer: { EmptyView() })
    }
}

extension PanelFrame where Footer == EmptyView {
    init(
        viewModel: QuickEditViewModel, panel: EditorPanel, onReset: (() -> Void)? = nil,
        @ViewBuilder fixed: () -> Fixed, @ViewBuilder content: () -> Content
    ) {
        self.init(viewModel: viewModel, panel: panel, onReset: onReset, fixed: fixed, content: content, footer: { EmptyView() })
    }
}

extension PanelFrame where Fixed == EmptyView {
    init(
        viewModel: QuickEditViewModel, panel: EditorPanel, onReset: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer
    ) {
        self.init(viewModel: viewModel, panel: panel, onReset: onReset, fixed: { EmptyView() }, content: content, footer: footer)
    }
}
