//
//  CreatorSetupTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("CreatorSetup")
struct CreatorSetupTests {
    /// The setup from the spec: Front, AirPods, 4K, 9:16, Large text.
    static func usual() -> CreatorSetup {
        var setup = CreatorSetup()
        setup.lens = .front
        setup.microphone = .input(id: "airpods-pro", name: "AirPods Pro")
        setup.resolution = .uhd4K
        setup.aspect = .portrait
        setup.textSize = PrompterTextSize.large.points
        setup.speed = 1.2
        return setup
    }

    @Test func startsFromCuesDefaults() {
        let setup = CreatorSetup()
        #expect(setup.lens == .front)
        #expect(setup.microphone == .automatic)
        #expect(setup.resolution == .hd1080)
        #expect(setup.frameRate == .fps30)
        #expect(setup.aspect == .portrait)
        #expect(setup.textSize == 36)
        #expect(setup.speed == ReadTime.naturalSpeed)
        #expect(setup.readingLine == .recommended)
        #expect(!setup.isMirrored)
        #expect(setup.showsSafeZones)
    }

    @Test func writesOnlyItsOwnFieldsIntoTheSettings() {
        var camera = CameraSettings()
        camera.countdown = .ten
        camera.codec = .h264
        var prompter = PrompterSettings()
        prompter.font = .serif
        let setup = Self.usual()

        let newCamera = setup.applied(to: camera)
        let newPrompter = setup.applied(to: prompter)

        #expect(newCamera.resolution == .uhd4K)
        #expect(newCamera.microphoneID == "airpods-pro")
        #expect(newCamera.microphoneName == "AirPods Pro")
        #expect(newCamera.countdown == .ten)
        #expect(newCamera.codec == .h264)
        #expect(newPrompter.size == 36)
        #expect(newPrompter.speed == 1.2)
        #expect(newPrompter.font == .serif)
        #expect(CreatorSetup(camera: newCamera, prompter: newPrompter) == setup)
    }

    @Test func comparesFieldByField() {
        var other = Self.usual()
        other.resolution = .hd1080
        other.isMirrored = true
        #expect(Self.usual().fields(differingFrom: other) == [.quality, .mirror])
    }

    @Test func labelsReadLikeTheScreen() {
        let setup = Self.usual()
        #expect(setup.label(for: .camera) == "Front")
        #expect(setup.label(for: .microphone) == "AirPods Pro")
        #expect(setup.label(for: .quality) == "4K")
        #expect(setup.label(for: .frameRate) == "30 fps")
        #expect(setup.label(for: .textSize) == "Large · 36 pt")
        #expect(setup.summary(of: [.quality, .format]) == "9:16 · 4K")
        #expect(setup.captureSummary == "4K · 9:16")
    }

    @Test func textSizePresetsMatchTheirPoints() {
        #expect(PrompterTextSize(points: 30) == .medium)
        #expect(PrompterTextSize(points: 28) == nil)
        #expect(PrompterTextSize(points: 44) == .extraLarge)
    }
}
