//
//  UniverseCoreSheet.swift
//  Cue Studio
//

import SwiftUI

/// 9.2 · tapping the core: "Your light. It grows with every video you share — no photo needed.", the topics as rings, the milestones and the
/// colour of the core. The colour is the one in Settings › Personalize.
struct UniverseCoreSheet: View {
    let snapshot: UniverseSnapshot

    @Environment(PersonalizationService.self) private var personalization
    @Environment(MilestoneService.self) private var milestones

    var body: some View {
        @Bindable var personalization = personalization
        ScrollView {
            VStack(spacing: 16) {
                SheetHeader(title: "Your universe", subtitle: subtitle)
                UniverseCore(color: personalization.coreColor, style: .preview)
                    .padding(.top, 6)
                Text("Your light. It grows with every video you share — no photo needed.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 12)
                GroupedCard(dividerInset: 16) {
                    ForEach(Array(snapshot.topics.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 12) {
                            Circle().fill(OnboardingTopic.color(at: index)).frame(width: 10, height: 10)
                            Text(entry.topic.label).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("ring").font(CueStudioFont.hud).foregroundStyle(Palette.ink2)
                        }
                        .font(.system(size: 17))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Milestones").foregroundStyle(Palette.ink).font(.system(size: 17))
                        Text(milestoneLine).font(.footnote).foregroundStyle(Palette.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("universeCore.milestones")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Core colour").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink2)
                    CoreColorSwatches(selection: $personalization.coreColor)
                        .padding(.horizontal, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 32, trailing: Metrics.gutter))
        }
        .accessibilityIdentifier("universeCore.sheet")
        .cueSheetChrome()
        .presentationDetents([.large])
    }

    private var subtitle: String {
        guard snapshot.total > 0 else { return String(localized: "NO VIDEOS SHARED YET") }
        let month = snapshot.firstShare.map { $0.formatted(.dateTime.month(.wide).locale(.interface)).uppercased() } ?? ""
        return String(localized: "\(snapshot.total) VIDEOS SHARED · SINCE \(month)")
    }

    /// "1st video ✓ · 10 videos ✓ · 25 videos — 2 to go": the milestones reached and the next one.
    private var milestoneLine: String {
        var parts: [String] = []
        for step in MilestoneService.steps {
            if step <= milestones.shares {
                parts.append(step == 1 ? String(localized: "1st video ✓") : String(localized: "\(step) videos ✓"))
            } else {
                parts.append(String(localized: "\(step) videos — \(step - milestones.shares) to go"))
                break
            }
        }
        return parts.joined(separator: " · ")
    }
}
