//
//  CaptureEnginePreviewOutputTests.swift
//  Cue StudioTests
//

import AVFoundation
import Testing
@testable import Cue_Studio

/// Turning on a background in the camera stopped the app: AVFoundation throws when preview-sized
/// buffers are asked for while the output still chooses its own dimensions.
@Suite("CaptureEngine preview output")
struct CaptureEnginePreviewOutputTests {
    @Test func previewSizedBuffersComeAfterManualDimensions() {
        let output = AVCaptureVideoDataOutput()
        CaptureEngine.configureForPreview(output)
        #expect(output.automaticallyConfiguresOutputBufferDimensions == false)
        #expect(output.deliversPreviewSizedOutputBuffers)
        #expect(output.alwaysDiscardsLateVideoFrames)
    }
}
