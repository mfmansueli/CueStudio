//
//  ProOpeningFrozenAt.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// UI tests taking pictures: the Pro opening stands still at this second of its timeline (`-uiTestProAt`).
    @Entry var proOpeningFrozenAt: Double?
}
