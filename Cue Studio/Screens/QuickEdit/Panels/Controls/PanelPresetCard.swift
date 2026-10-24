//
//  PanelPresetCard.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// A style as it draws on the video: the sample drawn by the export's own renderer over a frame of the take, its name under
/// it. Picked, it is ringed in yellow and marked with a check (never only a color); a favorite has a star, the style new work
/// starts in says "Default". The picked one may play its sample (`motion`), still with Reduce Motion. VoiceOver reads the
/// name, what the style looks like and its marks; the style's actions are its menu (`menu`), also VoiceOver actions.
struct PanelPresetCard<Menu: View>: View {
    let name: String
    let sample: UIImage?
    var motion: PresetCardMotion?
    let frame: UIImage?
    let isSelected: Bool
    var isFavorite = false
    var isDefault = false
    var summary: String?
    let identifier: String
    let action: () -> Void
    @ViewBuilder var menu: Menu

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 20

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                thumbnail
                Text(name)
                    .font(.system(.caption, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Palette.ink : Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 96)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePressCard)
        .contextMenu { menu }
        .accessibilityActions { menu }
        .accessibilityLabel(Text(name))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityHint(summary.map { Text($0) } ?? Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private var thumbnail: some View {
        ZStack {
            if let frame {
                Image(uiImage: frame).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Palette.Takes.thumbnailTop, Palette.Takes.thumbnailBottom], startPoint: .top, endPoint: .bottom)
            }
            Palette.Editor.presetCardDim
            if let motion, isSelected, !reduceMotion {
                TimelineView(.animation) { context in
                    playing(motion, at: context.date.timeIntervalSinceReferenceDate)
                }
            } else if let sample {
                still(sample)
            }
        }
        .frame(width: 96, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous)
                .strokeBorder(isSelected ? Palette.acc : Palette.Editor.presetCardBorder, lineWidth: isSelected ? 2.5 : 2)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(.caption2, weight: .heavy))
                    .foregroundStyle(Palette.accInk)
                    .frame(width: badgeSize, height: badgeSize)
                    .background(Palette.acc, in: Circle())
                    .overlay(Circle().strokeBorder(Palette.Editor.presetCardBadge, lineWidth: 1.5))
                    .padding(4)
            }
        }
        .overlay(alignment: .topLeading) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(Palette.chipOn)
                    .frame(width: badgeSize, height: badgeSize)
                    .background(Palette.Editor.presetCardBadge, in: Circle())
                    .padding(4)
            }
        }
        .overlay(alignment: .bottom) {
            if isDefault {
                Text("Default", comment: "A style card's mark: new work starts in this style")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(Palette.chipOn)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Palette.Editor.presetCardBadge, in: Capsule())
                    .padding(.bottom, 4)
            }
        }
    }

    private func still(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
    }

    /// The sample at `now`, in its loop: the drawing of the moment, the first coming in its way.
    private func playing(_ motion: PresetCardMotion, at now: TimeInterval) -> some View {
        let time = now.truncatingRemainder(dividingBy: max(motion.loop, 0.1))
        let current = motion.frames.last { $0.start <= time } ?? motion.frames[0]
        let first = motion.frames.first?.start ?? 0
        let since = time - first
        let fade = motion.fadeIn > 0 ? min(1, max(0, since / motion.fadeIn)) : 1
        let scale = PopEase.scale(from: motion.popScale, elapsed: since, duration: motion.popDuration)
        let rise = motion.riseDuration > 0 ? motion.rise * CGFloat(1 - pow(1 - min(1, max(0, since / motion.riseDuration)), 3)) : motion.rise
        return still(current.image)
            .scaleEffect(CGFloat(scale))
            .offset(y: motion.rise - rise)
            .opacity(time < first ? 0 : fade)
    }

    private var accessibilityValue: String {
        var marks: [String] = []
        if isFavorite { marks.append(String(localized: "Favorite")) }
        if isDefault { marks.append(String(localized: "Default for new videos")) }
        return marks.joined(separator: ", ")
    }
}

extension PanelPresetCard where Menu == EmptyView {
    init(
        name: String, sample: UIImage?, frame: UIImage?, isSelected: Bool, identifier: String, action: @escaping () -> Void
    ) {
        self.init(name: name, sample: sample, frame: frame, isSelected: isSelected, identifier: identifier, action: action) { EmptyView() }
    }
}
