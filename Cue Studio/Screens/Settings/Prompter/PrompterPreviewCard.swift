//
//  PrompterPreviewCard.swift
//  Cue Studio
//

import SwiftUI

/// "PREVIEW": a few lines of a script drawn with the prompter's settings (font, size, spacing, alignment, colour, mirror, flip and
/// the reading line), so every change shows before the creator leaves the page. It shows proportions, not the final look.
struct PrompterPreviewCard: View {
    let settings: PrompterSettings

    /// The preview is drawn at this fraction of the size on screen.
    private static let scale: Double = 0.56

    private var fontSize: CGFloat { max(10, CGFloat(settings.size * Self.scale)) }

    private var alignment: TextAlignment {
        switch settings.alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch settings.alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        ZStack(alignment: .top) {
            Text(script)
                .font(settings.font.font(size: fontSize).weight(.bold))
                .lineSpacing(max(0, (settings.lineSpacing - 1) * fontSize))
                .multilineTextAlignment(alignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .padding(.horizontal, 16 + CGFloat(settings.margin) * 0.4)
                .padding(.top, 32)
                .scaleEffect(x: settings.isMirrored ? -1 : 1, y: settings.isFlippedVertically ? -1 : 1)
            if settings.showsGuide {
                Rectangle()
                    .fill(Palette.acc)
                    .frame(height: 1.5)
                    .padding(.top, 58)
            }
            Text("PREVIEW")
                .font(CueStudioFont.hud)
                .tracking(1)
                .foregroundStyle(Palette.inkHint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 10, leading: 12, bottom: 0, trailing: 12))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .background(Palette.Editor.previewWell, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview of the prompter"))
        .accessibilityIdentifier("settings.prompterPreview")
    }

    /// The words already read are bright, the ones to come dimmer, and a cue is a small yellow tag.
    private var script: AttributedString {
        let color = settings.textColor.color
        var read = AttributedString("Three tiny habits changed my mornings. ")
        read.foregroundColor = color
        var cue = AttributedString(" PAUSE ")
        cue.font = CueStudioFont.hud
        cue.foregroundColor = .black
        cue.backgroundColor = Palette.acc
        var next = AttributedString(" One: no phone for the first twenty minutes.")
        next.foregroundColor = color.opacity(0.6)
        return read + (settings.showsCues ? cue : AttributedString(" ")) + next
    }
}
