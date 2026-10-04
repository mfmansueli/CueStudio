//
//  VoiceNudgeSlot.swift
//  Cue Studio
//

import SwiftUI

/// Where a My Cue Voice question shows on Scripts and Takes: the card for the one question that is next, or nothing.
/// "+ Something else" opens that question's sheet.
struct VoiceNudgeSlot: View {
    @Environment(VoiceNudgeService.self) private var nudges
    @Environment(AIStatus.self) private var aiStatus
    @State private var opened: VoicePersonalityItem?

    var body: some View {
        Group {
            if let next = nudges.current(isAIAvailable: aiStatus.isAvailable) {
                VoiceNudgeCard(item: next) { opened = next }
            }
        }
        .sheet(item: $opened) { VoicePersonalitySheet(item: $0) }
    }
}
