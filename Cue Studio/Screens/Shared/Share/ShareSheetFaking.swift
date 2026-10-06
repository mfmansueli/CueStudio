//
//  ShareSheetFaking.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// UI tests (`-uiTestFakeShareSheet`): a stand-in with two buttons takes the place of the system share sheet, which the Simulator can't drive.
    @Entry var fakesShareSheet = false
}
