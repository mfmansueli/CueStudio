//
//  OrbSlider.swift
//  Cue Studio
//

import SwiftUI

/// Every slider in Cue (v27): a planet for the thumb and a line of light for the track. Calm at rest,
/// alive while held (the orb grows, an orbit ring turns, the value lights up) and always precise: the
/// value is written in text, the orb follows the finger 1:1, sliding the finger down while holding
/// halves and then quarters the speed ("FINE"), a double-tap returns to the default and the default
/// has a soft tick. Stepped controls snap with a spring and mark each step with a small star.
///
/// - `.full`: label and value above a 26 pt orb on a 4 pt rail, optional end captions below.
/// - `.row`: the label on the left, a 20 pt orb on a 3 pt rail in the middle, the value on the right.
/// - `.compact`: a glass pill with a 16 pt orb, for over the camera or video ("SPEED  0.8×").
struct OrbSlider: View {
    enum Style { case full, row, compact }
    /// Where the trail starts: at the left end, or at zero in the middle (caption timing).
    enum Origin { case leading, center }

    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    var defaultValue: Double?
    var style: Style = .full
    var origin: Origin = .leading
    let label: String
    /// The value, always written ("140 wpm", "Large", "64 pt").
    let valueText: String
    /// What VoiceOver says for the value, when it differs ("140 words per minute").
    var spokenValue: String?
    var systemIcon: CueIcon?
    var minCaption: String?
    var maxCaption: String?
    /// Tapping the value opens a field to type a number (continuous controls).
    var allowsTyping = false
    /// Turns what was typed into a value; nil rejects it.
    var parse: ((String) -> Double?)?
    var accessibilityIdentifier: String?
    /// Called when a finger lands on the orb (true) and when it lets go (false), so a drag can be one undo step.
    var onEditingChanged: (Bool) -> Void = { _ in }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHeld = false
    @State private var dragAnchor: (value: Double, x: CGFloat)?
    @State private var precision: OrbSliderMath.Precision = .full
    @State private var isTyping = false
    @State private var typed = ""
    @AccessibilityFocusState private var isAccessibilityFocused: Bool
    @FocusState private var isKeyboardFocused: Bool

    private var math: OrbSliderMath { OrbSliderMath(range: range, step: step, defaultValue: defaultValue) }

    private var orbDiameter: CGFloat {
        switch style {
        case .full: 26
        case .row: 20
        case .compact: 16
        }
    }

    private var railHeight: CGFloat { style == .full ? 4 : 3 }

    // MARK: - Body

    var body: some View {
        Group {
            switch style {
            case .full: full
            case .row: row
            case .compact: compact
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(spokenValue ?? valueText))
        .accessibilityAdjustableAction { direction in
            let old = value
            switch direction {
            case .increment: value = math.incremented(value)
            case .decrement: value = math.decremented(value)
            @unknown default: break
            }
            feedback(from: old, to: value)
        }
        .accessibilityFocused($isAccessibilityFocused)
        .accessibilityIdentifier(accessibilityIdentifier ?? "orb.\(label)")
        .focusable()
        .focused($isKeyboardFocused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { nudge(-1) }
        .onKeyPress(.rightArrow) { nudge(1) }
        .alert(label, isPresented: $isTyping) {
            TextField(label, text: $typed).keyboardType(.decimalPad)
            Button("OK") { commitTyped() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Layouts

    private var full: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let systemIcon {
                    CueIconView(systemIcon, size: 22).foregroundStyle(Palette.ink2)
                }
                Text(label).font(.body).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                valueLabel
            }
            track
            if minCaption != nil || maxCaption != nil {
                HStack {
                    Text(minCaption ?? "")
                    Spacer()
                    Text(maxCaption ?? "")
                }
                .font(CueStudioFont.hud)
                .foregroundStyle(Palette.inkHint)
                .textCase(.uppercase)
            }
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            if let systemIcon {
                CueIconView(systemIcon, size: 22).foregroundStyle(Palette.ink2)
            }
            Text(label).font(.body).foregroundStyle(Palette.ink).lineLimit(2)
            track.frame(minWidth: 96, maxWidth: 130)
            Spacer(minLength: 4)
            valueLabel.frame(minWidth: 44, alignment: .trailing)
        }
    }

    private var compact: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(CueStudioFont.hud)
                .textCase(.uppercase)
                .foregroundStyle(Palette.ink2)
            track.frame(width: 110)
            valueLabel
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .glassNight(density: .thin)
    }

    private var valueLabel: some View {
        Button {
            guard allowsTyping, step == nil, isEnabled else { return }
            typed = ""
            isTyping = true
        } label: {
            VStack(alignment: .trailing, spacing: 1) {
                Text(valueText)
                    .font(CueStudioFont.hud)
                    .foregroundStyle(isHeld ? Color(hex: 0xFFF6C2) : Palette.accText)
                    .shadow(color: isHeld ? Palette.acc.opacity(0.7) : .clear, radius: 6)
                    .contentTransition(.numericText())
                if let fine = precision.label {
                    Text(fine).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: 0xFFF6C2))
                }
            }
            .frame(minHeight: Metrics.hitTarget / 2)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .allowsHitTesting(allowsTyping)
    }

    // MARK: - The track

    private var track: some View {
        GeometryReader { proxy in
            let length = max(1, proxy.size.width - orbDiameter)
            let fraction = math.fraction(of: value)
            let orbX = orbDiameter / 2 + length * fraction
            let originX = origin == .center ? orbDiameter / 2 + length / 2 : orbDiameter / 2
            ZStack(alignment: .leading) {
                // The rail: the whole range, quiet and always visible.
                Capsule()
                    .fill(Palette.sliderTrack)
                    .frame(height: railHeight)
                    .padding(.horizontal, orbDiameter / 2)
                // The trail: the value drawn as light, brighter while held.
                Capsule()
                    .fill(LinearGradient(
                        colors: [Palette.acc.opacity(isHeld ? 0.3 : 0.12), Palette.acc],
                        startPoint: orbX >= originX ? .leading : .trailing, endPoint: orbX >= originX ? .trailing : .leading
                    ))
                    .frame(width: abs(orbX - originX), height: railHeight)
                    .shadow(color: Palette.acc.opacity(isHeld ? 0.6 : 0.3), radius: isHeld ? 6 : 3)
                    .offset(x: min(orbX, originX))
                    .opacity(isEnabled ? 1 : 0)
                // The detent: the default value.
                if let defaultValue {
                    Rectangle()
                        .fill(Palette.ink3)
                        .frame(width: 1.5, height: orbDiameter * 0.7)
                        .offset(x: orbDiameter / 2 + length * math.fraction(of: defaultValue) - 0.75)
                }
                // The step stars.
                ForEach(Array(math.stepFractions.enumerated()), id: \.offset) { index, place in
                    FourPointStar()
                        .fill(index <= math.stepIndex(of: value) && isEnabled ? Color(hex: 0xFFE680) : Palette.ink3)
                        .frame(width: 8, height: 8)
                        .offset(x: orbDiameter / 2 + length * place - 4, y: orbDiameter / 2 + 2)
                }
                if isHeld { OrbitRing(orbDiameter: orbDiameter).frame(width: orbDiameter, height: orbDiameter).offset(x: orbX - orbDiameter / 2) }
                OrbThumb(diameter: orbDiameter, isHeld: isHeld, isEnabled: isEnabled)
                    .overlay {
                        if isAccessibilityFocused || isKeyboardFocused {
                            Circle()
                                .strokeBorder(Palette.infoText, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                                .frame(width: orbDiameter + 10, height: orbDiameter + 10)
                        }
                    }
                    .offset(x: orbX - orbDiameter / 2)
                    .animation(step == nil ? nil : CueMotion.animation(CueMotion.orbSnap, reduced: false), value: value)
                    .animation(CueMotion.animation(CueMotion.orbHold, reduced: reduceMotion), value: isHeld)
                    .onTapGesture(count: 2) { reset() }
            }
            .frame(height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .highPriorityGesture(drag(length: length))
        }
        .frame(height: Metrics.hitTarget)
        .opacity(isEnabled ? 1 : 0.6)
    }

    // MARK: - Interaction

    private func drag(length: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard isEnabled else { return }
                if dragAnchor == nil {
                    isHeld = true
                    onEditingChanged(true)
                    // A touch on the rail itself moves the orb there.
                    let touched = math.value(atFraction: Double((drag.startLocation.x - orbDiameter / 2) / length))
                    let old = value
                    value = touched
                    dragAnchor = (touched, drag.startLocation.x)
                    feedback(from: old, to: touched)
                }
                guard let anchor = dragAnchor else { return }
                let newPrecision = math.precision(forVerticalDrag: max(0, drag.translation.height))
                if newPrecision != precision {
                    // Re-anchor at the current value so the orb never jumps when the precision changes.
                    precision = newPrecision
                    dragAnchor = (value, drag.location.x)
                    return
                }
                let old = value
                let new = math.value(anchor: anchor.value, translation: drag.location.x - anchor.x, railLength: length, precision: precision)
                guard new != old else { return }
                value = new
                feedback(from: old, to: new)
            }
            .onEnded { _ in
                dragAnchor = nil
                isHeld = false
                onEditingChanged(false)
                precision = .full
            }
    }

    private func feedback(from old: Double, to new: Double) {
        guard old != new else { return }
        if math.reachesEnd(from: old, to: new) {
            Haptics.soft()
        } else if step != nil || math.crossesDetent(from: old, to: new) {
            Haptics.selection()
        }
    }

    private func reset() {
        guard isEnabled, let defaultValue else { return }
        let old = value
        value = math.snapped(defaultValue)
        feedback(from: old, to: value)
    }

    private func nudge(_ direction: Int) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        let old = value
        value = direction > 0 ? math.incremented(value) : math.decremented(value)
        feedback(from: old, to: value)
        return .handled
    }

    private func commitTyped() {
        let parsed = parse?(typed) ?? Double(typed.replacingOccurrences(of: ",", with: "."))
        guard let parsed else { return }
        value = math.snapped(parsed)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var speed = 140.0
    @Previewable @State var size = 2.0
    VStack(spacing: 28) {
        OrbSlider(
            value: $speed, range: 80...220, defaultValue: 150, label: "Speed", valueText: "\(Int(speed)) wpm",
            systemIcon: .speed, minCaption: "Slow", maxCaption: "Fast"
        )
        OrbSlider(value: $size, range: 0...3, step: 1, label: "Text size", valueText: ["S", "M", "L", "XL"][Int(size)], systemIcon: .textSize)
        OrbSlider(value: $speed, range: 80...220, style: .compact, label: "Speed", valueText: "\(Int(speed))")
    }
    .padding()
    .background(Palette.bg)
}
#endif
