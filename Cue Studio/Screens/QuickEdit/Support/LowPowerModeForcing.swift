//
//  LowPowerModeForcing.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// UI tests (`-uiTestLowPower`): the editor reads Low Power Mode as on, which the Simulator can't turn on.
    @Entry var forcesLowPowerMode = false
}
