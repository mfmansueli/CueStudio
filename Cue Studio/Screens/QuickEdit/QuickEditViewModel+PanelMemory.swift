//
//  QuickEditViewModel+PanelMemory.swift
//  Cue Studio
//

import Foundation

/// A panel opens on the tab and Advanced it was left with in this video (owner, canvas 2 R7, 07/11/2026), per item where its
/// controls are an item's: another clip, text or photo opens as it was left for that one, or as the panel starts. A path that
/// opens a panel on a given tab (Animation from a text's bar, Clean up on its row) still sets it after.
extension QuickEditViewModel {
    /// Keeps `previous`'s tab and Advanced for the item they were for, and puts `next`'s back for what is picked now.
    func swapPanelState(from previous: EditorPanel?, to next: EditorPanel?) {
        if let previous {
            panelMemory.remember(PanelMemory.State(tab: panelTab, showsAdvanced: showsAdvanced), of: previous, item: panelStateItem)
        }
        panelStateItem = selection?.itemID
        let state = next.map { panelMemory.state(of: $0, item: panelStateItem) } ?? PanelMemory.State()
        panelTab = state.tab
        showsAdvanced = state.showsAdvanced
    }

    /// Another item picked while its panel stays open: the panel shows how it was left for that one.
    func panelPickChanged() {
        guard let panel, panel.remembersPerItem, selection?.itemID != panelStateItem else { return }
        swapPanelState(from: panel, to: panel)
    }
}
