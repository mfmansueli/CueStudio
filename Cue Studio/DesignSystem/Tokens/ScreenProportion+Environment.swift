//
//  ScreenProportion+Environment.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// Whether the interface's type follows the iPhone's width (`ScreenProportion`). The editor turns it off: its tools are drawn at one size
    /// on every iPhone, and a shared control in it (a slider, a chip) is drawn at the editor's size, not a step bigger on a Pro Max (the
    /// owner, 30/10/2026). Dynamic Type still applies.
    @Entry var typeFollowsScreenWidth = true
}
