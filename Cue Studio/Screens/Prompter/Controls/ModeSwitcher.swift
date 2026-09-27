//
//  ModeSwitcher.swift
//  Cue Studio
//

import SwiftUI

/// Selfie | Studio segmented control over the camera.
struct ModeSwitcher: View {
    let mode: PrompterMode
    let onChange: (PrompterMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PrompterMode.allCases) { option in
                Button {
                    onChange(option)
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(option == mode ? Color.black : Color.white)
                        .padding(.horizontal, 16)
                        .frame(maxHeight: .infinity)
                        .background(option == mode ? Color.white : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option == mode ? .isSelected : [])
                .accessibilityIdentifier("prompter.mode.\(option.rawValue)")
            }
        }
        .padding(3)
        .frame(height: 40)
        .glassEffect(.regular, in: Capsule())
        // The mode names never truncate; the platform chip beside them gives way first.
        .layoutPriority(1)
    }
}

#if DEBUG
#Preview {
    ModeSwitcher(mode: .selfie, onChange: { _ in })
        .padding()
        .background(CameraFeedPlaceholder())
}
#endif
