//
//  SendOffFrozenAt.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// UI tests taking pictures: the send-off stands still at this second (`-uiTestSendOffAt`).
    @Entry var sendOffFrozenAt: Double?
}
