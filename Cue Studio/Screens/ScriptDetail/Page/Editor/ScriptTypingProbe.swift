//
//  ScriptTypingProbe.swift
//  Cue Studio
//

#if DEBUG
import QuartzCore
import UIKit

/// Debug, `-uiTestTypingProbe`: how fluid typing in a script's words is on a real iPhone, as the creator feels it. A display link at 60
/// frames a second runs while the words have the keyboard and counts every frame the main thread was too busy to draw (a hitch: one that
/// came more than half a frame late), how late the worst one was, and how long a letter took to reach the screen (letters that share a
/// frame count once, from the first). Once the typing pauses, the words' accessibility label carries the numbers, which
/// `PerformanceDeviceUITests` reads: "… · probe keys=40 keyFrames=40 keyP95=12.1 keyMax=18.3 frames=900 hitches=0 hitchMs=0.0
/// worstMs=16.9". Typing must be as fluid as in Notes, whatever the script's length (the owner, 03/11/2026).
@MainActor
final class ScriptTypingProbe: NSObject {
    static var isAsked: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestTypingProbe") }

    /// Each step's time while the words are typed in (`ScriptTypingTimeline`): how often it ran, the most it took, all it took.
    private static var steps: [String: (count: Int, max: Double, total: Double)] = [:]

    static func note(_ step: String, seconds: Double) {
        var measured = steps[step] ?? (0, 0, 0)
        measured.count += 1
        measured.max = max(measured.max, seconds)
        measured.total += seconds
        steps[step] = measured
    }

    private weak var view: UIView?
    private let label: String
    private var link: CADisplayLink?
    private var lastFrame: CFTimeInterval?
    private var keyAt: CFTimeInterval?
    private var lastKey: CFTimeInterval = 0
    private var latencies: [Double] = []
    private var keys = 0
    private var frames = 0
    private var hitches = 0
    private var hitchTime: Double = 0
    private var worstGap: Double = 0
    /// Hitches by how long after the last letter they came: on the letter (< 0.2 s), when the page catches up at the pause (0.2–0.6 s),
    /// when the words are saved (0.9–1.4 s), or otherwise.
    private var hitchesBy: [String: Int] = [:]
    private var isPublished = true

    init(view: UIView) {
        self.view = view
        label = view.accessibilityLabel ?? ""
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// The words' height on screen against a whole measure, before the first letter.
    private var openGap: CGFloat?

    func keyPressed() {
        if openGap == nil, let view = view as? ScriptTextView {
            openGap = ScriptTextView.freshHeight(of: view.textStorage.string, style: view.style, width: view.bounds.width) - view.bounds.height
        }
        let now = CACurrentMediaTime()
        keys += 1
        if keyAt == nil { keyAt = now }
        lastKey = now
        isPublished = false
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastFrame = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        if let keyAt {
            latencies.append(now - keyAt)
            self.keyAt = nil
        }
        // Counted from the first letter: the page opening isn't typing.
        if let lastFrame, !latencies.isEmpty {
            let gap = link.timestamp - lastFrame
            frames += 1
            if gap > link.duration * 1.5 {
                hitches += 1
                hitchTime += gap - link.duration
                // When the late frame began: the gap's start, after the last letter.
                let since = lastFrame - lastKey
                let kind = since < 0.2 ? "onKey" : since < 0.6 ? "atPause" : since > 0.9 && since < 1.4 ? "atSave" : "other"
                hitchesBy[kind, default: 0] += 1
            }
            worstGap = max(worstGap, gap)
        }
        lastFrame = link.timestamp
        if !isPublished, now - lastKey > 0.6 { publish() }
    }

    private func publish() {
        isPublished = true
        let sorted = latencies.sorted()
        let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        let numbers = [
            "keys=\(keys)", "keyFrames=\(sorted.count)", "keyP95=\(Self.ms(p95))", "keyMax=\(Self.ms(sorted.last ?? 0))", "frames=\(frames)",
            "hitches=\(hitches)", "hitchMs=\(Self.ms(hitchTime))", "worstMs=\(Self.ms(worstGap))",
        ] + hitchesBy.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        let measured = Self.steps.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.count)x\(Self.ms($0.value.max))/\(Self.ms($0.value.total))" }
        // The words' height on screen against a whole measure of them: anything but 0 is a line cut off or a gap under the words.
        var height: [String] = []
        if let view = view as? ScriptTextView {
            let told = view.fittingHeight(for: view.bounds.width)
            let whole = ScriptTextView.freshHeight(of: view.textStorage.string, style: view.style, width: view.bounds.width)
            height = [
                "heightGap=\(String(format: "%.1f", whole - view.bounds.height))", "toldGap=\(String(format: "%.1f", whole - told))",
                "openGap=\(String(format: "%.1f", openGap ?? .nan))",
            ]
        }
        view?.accessibilityLabel = label + " · probe " + (numbers + height + measured).joined(separator: " ")
    }

    private static func ms(_ seconds: Double) -> String {
        String(format: "%.1f", seconds * 1000)
    }
}
#endif
