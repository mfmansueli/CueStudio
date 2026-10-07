//
//  BugHuntUITests.swift
//  Cue StudioUITests
//

import XCTest

/// A crawl through the whole app the way a person with nothing to do would use it: on every screen it taps each control, looks at what came
/// of it, goes back, and carries on into whatever opened. It never fails on what it finds. It writes two files for each part of the app:
/// - `<run>-<part>-map.txt`, one line for each control: what it is called, what opened (what is new on the screen), the ways out of there,
///   and "NOTHING HAPPENED" when a tap changed nothing, so that what each button promises can be read against where it leads;
/// - `<run>-<part>-findings.txt`: a crash, a way out that is missing, text that is a raw key or a format specifier, a control with no name,
///   controls on top of each other, text running off the screen.
/// A picture is kept of every new screen. When a tap leaves the crawl somewhere it can't come back from, it starts over from the tab and
/// repeats the taps that led to the screen it was exploring. Opt-in:
/// `TEST_RUNNER_CUE_HUNT_DIR=<folder> [TEST_RUNNER_CUE_HUNT_NAME=run] [TEST_RUNNER_CUE_HUNT_LANG=pt-BR] [TEST_RUNNER_CUE_HUNT_SEEDED=0]
/// [TEST_RUNNER_CUE_HUNT_PRO=1] [TEST_RUNNER_CUE_HUNT_NOAI=1] scripts/test.sh only "Cue StudioUITests/BugHuntUITests"`.
@MainActor
final class BugHuntUITests: XCTestCase {
    private var app: XCUIApplication!
    private var directory: URL!
    private var runName = "hunt"
    private var findings: [String] = []
    private var map: [String] = []
    private var seen = Set<String>()
    private var shots = 0
    private var taps = 0
    private var started = Date()
    private var screen = CGRect.zero
    private var tabIndex = 0
    private var part = "part"

    /// A crawl stops itself a little before the test plan would stop it.
    private let budget: TimeInterval = 540

    override func setUp() {
        continueAfterFailure = true
        executionTimeAllowance = 590
    }

    // MARK: - The crawls, one for each part of the app

    func testScriptsAndTheirPages() throws { try crawl(tab: 0, depth: 3, part: "scripts") }
    func testTakesAndTheEditor() throws { try crawl(tab: 1, depth: 3, part: "takes") }
    func testRecorder() throws { try crawl(tab: 2, depth: 2, part: "recorder") }
    func testProfileAndMyCueVoice() throws { try crawl(tab: 3, depth: 4, part: "profile") }
    func testSettings() throws { try crawl(tab: 4, depth: 3, part: "settings") }

    /// The accessibility tree of the main screens, to read what has no name.
    func testDumpTheScreens() throws {
        try begin()
        func dump(_ name: String) {
            sleep(1)
            try? app.debugDescription.write(to: directory.appending(path: "dump-\(name).txt"), atomically: true, encoding: .utf8)
        }
        dump("scripts")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        sleep(2)
        dump("page")
        app.descendants(matching: .any)["page.editor"].firstMatch.tap()
        dump("page-editing")
        app.buttons["editor.doneButton"].firstMatch.tap()
        app.pageBackButton.tap()
        app.cueTabBar.buttons["Takes"].tap()
        dump("takes")
        let video = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.'")).firstMatch
        if video.waitForExistence(timeout: 5) { video.tap(); dump("review") }
    }

    private func crawl(tab: Int, depth: Int, part: String) throws {
        try begin()
        self.part = part
        tabIndex = tab
        resetToRoot()
        explore(trail: [], depth: 0, maxDepth: depth)
        try end(part)
    }

    private func begin() throws {
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["CUE_HUNT_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_HUNT_DIR to run the hunt") }
        directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        runName = env["CUE_HUNT_NAME"] ?? "hunt"
        started = Date()
        app = CueApp.launch(
            seeded: env["CUE_HUNT_SEEDED"] != "0", pro: env["CUE_HUNT_PRO"] == "1", ai: env["CUE_HUNT_NOAI"] == "1" ? .none : .stub,
            sampleVideo: true, appLanguage: env["CUE_HUNT_LANG"], animations: false,
            extraArguments: ["-uiTestFakeShareSheet", "-uiTestPermissions", "granted"]
        )
        _ = app.cueTabBar.waitForExistence(timeout: 25)
        sleep(2)
        screen = app.frame
    }

    private func end(_ part: String) throws {
        self.part = part
        flush()
    }

    /// The files as they stand: written after every tap, so a crawl cut short (a screen that stops answering) still leaves what it saw.
    private func flush() {
        let head = "# \(runName)-\(part): \(taps) taps in \(Int(Date().timeIntervalSince(started))) s, \(shots) pictures, \(findings.count) findings"
        try? ([head, ""] + findings).joined(separator: "\n").write(
            to: directory.appending(path: "\(runName)-\(part)-findings.txt"), atomically: true, encoding: .utf8
        )
        try? map.joined(separator: "\n").write(to: directory.appending(path: "\(runName)-\(part)-map.txt"), atomically: true, encoding: .utf8)
    }

    private var timeIsUp: Bool { Date().timeIntervalSince(started) > budget }

    // MARK: - Reading the screen

    /// A control that can be tapped: where it is and what it is called.
    private struct Item: Hashable {
        let label: String
        let id: String
        let type: XCUIElement.ElementType
        let frame: CGRect
        var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
        var key: String { "\(type.rawValue)|\(id)|\(label)" }
        var called: String { label.isEmpty ? (id.isEmpty ? "(no name)" : id) : label }
    }

    /// Controls that must never be tapped by a crawl: they erase, buy, sign out or leave the app.
    private static let denied = [
        "delete", "erase", "reset", "sign out", "stop using", "restore", "subscribe", "free trial", "purchase", "buy", "open settings",
        "apple id", "sign in", "log out", "forget", "clear all", "start free trial", "sheet grabber",
    ]

    /// The ways back from a screen, by what they are called.
    private static let backLabels = ["close", "done", "cancel", "not now", "back", "dismiss", "ok", "got it", "skip", "later", "no thanks"]
    private static let tabNames = ["scripts", "takes", "record", "profile", "settings"]

    private func snapshot() -> XCUIElementSnapshot? {
        do { return try app.snapshot() } catch {
            findings.append("• could not read the screen: \(error.localizedDescription)")
            return nil
        }
    }

    private func flatten(_ snapshot: XCUIElementSnapshot) -> [XCUIElementSnapshot] {
        [snapshot] + snapshot.children.flatMap(flatten)
    }

    private func visible(_ element: XCUIElementSnapshot) -> Bool {
        element.frame.width > 0 && screen.intersects(element.frame)
    }

    /// What is on the screen right now, as one string: every name, value and place that is in view.
    private func signature(_ snapshot: XCUIElementSnapshot) -> String {
        flatten(snapshot).filter(visible).map { "\($0.elementType.rawValue)\($0.identifier)\($0.label)\($0.value as? String ?? "")" }.joined(separator: "|")
    }

    /// The same without the values (a switch, a count): what tells one screen from another.
    private func outline(_ snapshot: XCUIElementSnapshot) -> Set<String> {
        Set(flatten(snapshot).filter(visible).map { "\($0.elementType.rawValue)\($0.identifier)\($0.label)" })
    }

    /// Whether two outlines are the same screen, give or take a toast, a cursor or an animation in the middle.
    private func sameScreen(_ lhs: Set<String>, _ rhs: Set<String>) -> Bool {
        Double(lhs.intersection(rhs).count) / Double(max(1, lhs.union(rhs).count)) >= 0.85
    }

    /// The names on a screen (texts and controls), top to bottom: what a person reads.
    private func names(_ snapshot: XCUIElementSnapshot) -> [String] {
        let kinds: [XCUIElement.ElementType] = [.staticText, .button, .cell, .switch, .textField, .link, .navigationBar]
        return flatten(snapshot).filter { kinds.contains($0.elementType) && !$0.label.isEmpty && visible($0) }
            .sorted { $0.frame.minY < $1.frame.minY }.map(\.label)
    }

    private func isExit(_ element: XCUIElementSnapshot) -> Bool {
        guard element.elementType == .button, element.frame.width > 10, visible(element) else { return false }
        return Self.backLabels.contains(element.label.lowercased()) || element.identifier == "sheet.closeButton" || element.identifier == "BackButton"
            || (element.frame.minX < 80 && element.frame.minY < 130)
    }

    /// The ways a person can leave a screen: close, back, done, cancel.
    private func exits(_ snapshot: XCUIElementSnapshot) -> [String] {
        flatten(snapshot).filter(isExit).map { $0.label.isEmpty ? $0.identifier : $0.label }
    }

    private func isTabBarButton(_ element: XCUIElementSnapshot) -> Bool {
        element.elementType == .button && element.frame.minY > screen.height - 110 && Self.tabNames.contains(element.label.lowercased())
    }

    private func candidates(in snapshot: XCUIElementSnapshot) -> [Item] {
        let kinds: [XCUIElement.ElementType] = [.button, .cell, .switch, .link, .menuItem, .slider, .stepper]
        // What the keyboard covers is the keyboard's: a crawl that typed on it would write nonsense and change its language.
        let keyboard = flatten(snapshot).first { $0.elementType == .keyboard }?.frame ?? .null
        let all = flatten(snapshot).filter { element in
            kinds.contains(element.elementType) && element.isEnabled && element.frame.width > 10 && element.frame.height > 10
                && screen.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) && !isTabBarButton(element)
                && !keyboard.contains(CGPoint(x: element.frame.midX, y: element.frame.midY))
        }
        let items = all.compactMap { element -> Item? in
            let label = element.label.isEmpty ? element.title : element.label
            let lowered = (label + " " + element.identifier).lowercased()
            guard !Self.denied.contains(where: lowered.contains), !isExit(element) else { return nil }
            return Item(label: label, id: element.identifier, type: element.elementType, frame: element.frame)
        }
        // A control that is only the inside of another (its count, its icon) is the same control.
        let outer = items.filter { item in !items.contains { $0 != item && $0.frame.contains(item.frame) && $0.frame != item.frame } }
        var keys = Set<String>()
        return outer.filter { keys.insert($0.key).inserted }
    }

    private func tap(_ item: Item) {
        taps += 1
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: item.center.x, dy: item.center.y)).tap()
    }

    private func tapElement(_ element: XCUIElementSnapshot) {
        taps += 1
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: element.frame.midX, dy: element.frame.midY)).tap()
    }

    // MARK: - Getting around

    /// Closes whatever is open and shows the tab's own screen.
    private func resetToRoot() {
        for _ in 0..<4 {
            guard let snapshot = snapshot(), let exit = flatten(snapshot).first(where: isModalExit) else { break }
            tapElement(exit)
            usleep(700_000)
        }
        let bar = app.cueTabBar
        if bar.waitForExistence(timeout: 3) {
            bar.buttons.element(boundBy: tabIndex).tap()
            usleep(500_000)
            bar.buttons.element(boundBy: tabIndex).tap()
        }
        sleep(1)
    }

    private func isModalExit(_ element: XCUIElementSnapshot) -> Bool {
        element.identifier == "sheet.closeButton"
            || (element.elementType == .button && Self.backLabels.contains(element.label.lowercased()) && element.frame.minY < screen.height - 120)
    }

    /// The screen the trail of taps led to, from the tab's own screen; false when a tap on the way can't be found any more.
    private func replay(_ trail: [Item]) -> Bool {
        resetToRoot()
        for step in trail {
            guard let snapshot = snapshot(), let item = find(step.key, in: snapshot) else { return false }
            tap(item)
            usleep(900_000)
        }
        return true
    }

    private func find(_ key: String, in snapshot: XCUIElementSnapshot) -> Item? {
        if let item = candidates(in: snapshot).first(where: { $0.key == key }) { return item }
        return flatten(snapshot).compactMap { element -> Item? in
            let item = Item(label: element.label, id: element.identifier, type: element.elementType, frame: element.frame)
            return item.key == key && visible(element) ? item : nil
        }.first
    }

    /// Back to the screen the tap started from: a close button, a back button, a drag down, or a tap beside a menu.
    private func goBack(to reference: Set<String>) -> Bool {
        for attempt in 0..<4 {
            guard let snapshot = snapshot() else { return false }
            if sameScreen(outline(snapshot), reference) { return true }
            if menuIsOpen(snapshot) { closeMenu(); continue }
            let elements = flatten(snapshot)
            if let exit = elements.first(where: { $0.identifier == "sheet.closeButton" || $0.identifier == "BackButton" }) ?? elements.first(where: isExit) {
                tapElement(exit)
            } else if attempt < 2 {
                app.swipeDown(velocity: .fast)
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04)).tap()
            }
            usleep(800_000)
            guard app.state == .runningForeground else { return false }
        }
        return snapshot().map { sameScreen(outline($0), reference) } ?? false
    }

    // MARK: - Menus

    /// A menu (the "More" of a page) is a layer on top of the screen, with its own buttons: it is read and walked on its own.
    private func menuIsOpen(_ snapshot: XCUIElementSnapshot) -> Bool {
        flatten(snapshot).contains { $0.identifier == "_UIContextMenuActionsOnlyView" } || menuEntries(snapshot).count >= 3
    }

    private func closeMenu() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)).tap()
        usleep(700_000)
    }

    /// The entries of an open menu, and whether each leads on to a second list (it has a chevron).
    private func menuEntries(_ snapshot: XCUIElementSnapshot) -> [(item: Item, isSubmenu: Bool)] {
        flatten(snapshot).filter { $0.elementType == .cell && $0.frame.width < 330 && $0.frame.height > 30 && visible($0) }.compactMap { cell in
            guard let button = cell.children.first(where: { $0.elementType == .button }) else { return nil }
            let item = Item(label: button.label, id: button.identifier, type: .button, frame: button.frame)
            return (item, flatten(button).contains { $0.label == "Forward" })
        }
    }

    /// Opens a menu, reads what it offers, and uses each entry once, going back to the screen it belongs to after each.
    private func exploreMenu(opener: Item, entries: [(item: Item, isSubmenu: Bool)], trail: [Item], maxDepth: Int, reference: Set<String>) -> Bool {
        let depth = trail.count
        line(depth, "▸ “\(opener.called)” [\(opener.id)] → MENU: \(entries.map { $0.item.called + ($0.isSubmenu ? " ›" : "") }.joined(separator: ", "))")
        for entry in entries where !Self.denied.contains(where: { entry.item.called.lowercased().contains($0) }) {
            if timeIsUp { return false }
            if let now = snapshot(), !menuIsOpen(now) { tap(opener); usleep(900_000) }
            guard let open = snapshot(), let current = menuEntries(open).first(where: { $0.item.label == entry.item.label }) else { continue }
            tap(current.item)
            usleep(1_000_000)
            guard app.state == .runningForeground else {
                findings.append("✘ CRASH after choosing “\(entry.item.called)” in the menu of “\(opener.called)” at \(describe(trail))")
                line(depth + 1, "▸ “\(entry.item.called)” → ✘ CRASH")
                return false
            }
            guard let after = snapshot() else { continue }
            if menuIsOpen(after) {
                let names = menuEntries(after).map(\.item.called).joined(separator: ", ")
                line(depth + 1, "▸ “\(entry.item.called)” → \(entry.isSubmenu ? "a second list" : "the menu stayed open"): \(names)")
                closeMenu()
                continue
            }
            recordMenuChoice(entry.item, after: after, reference: reference, trail: trail + [opener], maxDepth: maxDepth)
            if !goBack(to: reference), !replay(trail) { return false }
        }
        if let last = snapshot(), menuIsOpen(last) { closeMenu() }
        return true
    }

    private func recordMenuChoice(_ item: Item, after: XCUIElementSnapshot, reference: Set<String>, trail: [Item], maxDepth: Int) {
        let depth = trail.count
        let arrived = names(after).filter { !reference.contains($0) }
        let ways = exits(after)
        if outline(after) == reference, arrived.isEmpty {
            line(depth, "▸ “\(item.called)” → ⚠ NOTHING VISIBLE HAPPENED")
            findings.append("⚠ MENU ENTRY WITH NO VISIBLE EFFECT: “\(item.called)” in the menu of “\(trail.last?.called ?? "")” at \(describe(trail))")
            return
        }
        let opens = arrived.prefix(5).map { "“\($0.prefix(40))”" }.joined(separator: ", ")
        line(depth, "▸ “\(item.called)” → \(opens) · ways out: \(ways.isEmpty ? "NONE" : ways.joined(separator: ", "))")
        if !sameScreen(outline(after), reference) { explore(trail: trail + [item], depth: depth + 1, maxDepth: maxDepth) }
    }

    // MARK: - The crawl

    private func line(_ depth: Int, _ text: String) { map.append(String(repeating: "    ", count: depth) + text) }

    private func describe(_ trail: [Item]) -> String { trail.isEmpty ? "the tab" : trail.map { "“\($0.called)”" }.joined(separator: " › ") }

    private func crashed(_ item: Item, at trail: [Item]) -> Bool {
        guard app.state != .runningForeground else { return false }
        findings.append("✘ CRASH or the app left the foreground after tapping “\(item.called)” [\(item.id)] at \(describe(trail))")
        line(trail.count, "▸ “\(item.called)” [\(item.id)] → ✘ CRASH")
        return true
    }

    private func explore(trail: [Item], depth: Int, maxDepth: Int) {
        guard let first = snapshot() else { return }
        inspect(first, trail: trail)
        guard depth < maxDepth else { return }
        var tried = Set<String>()
        for page in 0..<4 {
            guard let current = snapshot() else { return }
            let before = signature(current)
            for item in candidates(in: current) where tried.insert(item.key).inserted {
                if timeIsUp { findings.append("• time is up at \(describe(trail))"); return }
                if crashed(item, at: trail) || !tapAndRecord(item, current: current, trail: trail, maxDepth: maxDepth) { return }
            }
            guard page < 3 else { break }
            app.swipeUp()
            usleep(700_000)
            if let moved = snapshot(), signature(moved) == before { break }
        }
        for _ in 0..<4 { app.swipeDown() }
        usleep(400_000)
    }

    /// One tap: what it did, and the way back. False when the crawl can't go on.
    private func tapAndRecord(_ item: Item, current: XCUIElementSnapshot, trail: [Item], maxDepth: Int) -> Bool {
        let reference = snapshot() ?? current
        let referenceSignature = signature(reference)
        let referenceOutline = outline(reference)
        let referenceNames = Set(names(reference))
        let depth = trail.count
        tap(item)
        usleep(900_000)
        defer { flush() }
        if crashed(item, at: trail) { return false }
        let asked = Date()
        guard let after = snapshot() else { return true }
        if Date().timeIntervalSince(asked) > 8 {
            findings.append("⚠ SLOW: reading the screen after “\(item.called)” at \(describe(trail)) took \(Int(Date().timeIntervalSince(asked))) s")
        }
        let changed = signature(after) != referenceSignature
        if answerAlert(after, item: item, depth: depth) { return true }
        if menuIsOpen(after) {
            let entries = menuEntries(after)
            inspect(after, trail: trail + [item])
            return exploreMenu(opener: item, entries: entries, trail: trail, maxDepth: maxDepth, reference: referenceOutline)
        }
        if [.switch, .slider, .stepper].contains(item.type) {
            line(depth, "▸ “\(item.called)” [\(item.id)] (\(item.type == .switch ? "switch" : "control")) → \(changed ? "changed" : "⚠ NOTHING HAPPENED")")
            if !changed { findings.append("⚠ DEAD CONTROL: “\(item.called)” [\(item.id)] at \(describe(trail)) does nothing") }
            inspect(after, trail: trail + [item])
            if item.type == .switch { tap(item); usleep(500_000) }
            return true
        }
        guard changed else {
            line(depth, "▸ “\(item.called)” [\(item.id)] → ⚠ NOTHING HAPPENED")
            findings.append("⚠ DEAD BUTTON: “\(item.called)” [\(item.id)] at \(describe(trail)) does nothing visible")
            return true
        }
        let arrived = names(after).filter { !referenceNames.contains($0) }
        let ways = exits(after)
        let opens = arrived.prefix(5).map { "“\($0.prefix(40))”" }.joined(separator: ", ")
        line(depth, "▸ “\(item.called)” [\(item.id)] → opens: \(opens) · ways out: \(ways.isEmpty ? "NONE" : ways.joined(separator: ", "))")
        if ways.isEmpty, !arrived.isEmpty {
            findings.append("⚠ POSSIBLE DEAD END: after “\(item.called)” at \(describe(trail)) no way out is visible (opens \(arrived.prefix(3).joined(separator: ", ")))")
        }
        explore(trail: trail + [item], depth: depth + 1, maxDepth: maxDepth)
        if !goBack(to: referenceOutline), !replay(trail) {
            findings.append("⚠ LOST: after “\(item.called)” at \(describe(trail)) the way back did not return, and the taps could not be repeated")
            line(depth, "    ⚠ could not get back from here")
            return false
        }
        return true
    }

    /// A system alert: what it says, then it is answered with its first button.
    private func answerAlert(_ snapshot: XCUIElementSnapshot, item: Item, depth: Int) -> Bool {
        guard let alert = flatten(snapshot).first(where: { $0.elementType == .alert }) else { return false }
        let text = ([alert.label] + flatten(alert).filter { $0.elementType == .staticText }.map(\.label)).joined(separator: " · ")
        line(depth, "▸ “\(item.called)” [\(item.id)] → alert: \(text.prefix(140))")
        if let button = flatten(alert).first(where: { $0.elementType == .button && $0.frame.height > 10 }) {
            tapElement(button)
            usleep(600_000)
        }
        return true
    }

    // MARK: - What to look at on a screen

    private static let rawPatterns: [(String, String)] = [
        (#"%[0-9]*\$?[@dflsu]|%lld|%ld"#, "a format specifier shows"),
        (#"Optional\("#, "an Optional shows"),
        (#"\bnil\b|\bNaN\b|\binf\b"#, "nil, NaN or inf shows"),
        (#"\\\("#, "an interpolation shows"),
        (#"(?i)\blorem ipsum\b|\btodo\b|\bfixme\b|\bplaceholder\b"#, "placeholder text shows"),
        (#"^[a-z]+(\.[A-Za-z0-9_\-]+){1,}$"#, "an identifier shows as text"),
    ]

    private func inspect(_ snapshot: XCUIElementSnapshot, trail: [Item]) {
        guard seen.insert(signature(snapshot)).inserted else { return }
        let place = describe(trail)
        let elements = flatten(snapshot).filter(visible)
        textProblems(in: elements, place: place)
        for element in elements where element.elementType == .button && element.label.isEmpty && element.title.isEmpty && element.frame.width > 10 {
            findings.append("• a button with no name [\(element.identifier)] at \(place) (\(Int(element.frame.width))×\(Int(element.frame.height)))")
        }
        let buttons = elements.filter { $0.elementType == .button && $0.frame.width > 20 && $0.frame.height > 20 }
        for (index, lhs) in buttons.enumerated() {
            for rhs in buttons[(index + 1)...] where overlapsWithoutNesting(lhs, rhs) {
                findings.append("• controls on top of each other: “\(lhs.label)” and “\(rhs.label)” at \(place)")
            }
        }
        shot(trail.last?.called ?? "tab")
    }

    private func textProblems(in elements: [XCUIElementSnapshot], place: String) {
        let kinds: [XCUIElement.ElementType] = [.staticText, .button, .textField, .textView, .cell, .link]
        for element in elements where kinds.contains(element.elementType) && !element.label.isEmpty {
            let text = element.label
            for (pattern, what) in Self.rawPatterns where text.range(of: pattern, options: .regularExpression) != nil {
                findings.append("✘ \(what): “\(text.prefix(80))” [\(element.identifier)] at \(place)")
            }
            if element.elementType == .staticText, element.frame.minX < -1 || element.frame.maxX > screen.width + 1 {
                findings.append("• text runs off the screen: “\(text.prefix(60))” at \(place)")
            }
        }
    }

    private func overlapsWithoutNesting(_ lhs: XCUIElementSnapshot, _ rhs: XCUIElementSnapshot) -> Bool {
        // The list slides under the dock and the keyboard by design; what is compared is the controls of one layer.
        let beneath = [lhs, rhs].contains { $0.identifier.hasPrefix("scripts.row.") || $0.identifier.hasPrefix("takes.video.") || isTabBarButton($0) }
        let overlap = lhs.frame.intersection(rhs.frame)
        guard !beneath, !overlap.isNull, lhs.frame.minY < screen.height * 0.55 || lhs.frame.maxY < screen.height * 0.9,
              !lhs.frame.contains(rhs.frame), !rhs.frame.contains(lhs.frame) else { return false }
        let smaller = min(lhs.frame.width * lhs.frame.height, rhs.frame.width * rhs.frame.height)
        return overlap.width * overlap.height > smaller * 0.4
    }

    private func shot(_ label: String) {
        guard shots < 200 else { return }
        shots += 1
        let safe = label.map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined().prefix(36)
        let file = String(format: "%@-%03d-%@.png", runName, shots, String(safe))
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: file))
    }
}
