//
//  SendableConformances.swift
//  Cue Studio
//

import AVFoundation

// Retroactive Sendable conformances for framework types that are not annotated yet.
// Remove each one as soon as the SDK marks the type Sendable (the compiler will then warn).

/// `AVCaptureSession` is shared between the capture actor (which configures and runs it on its own
/// serial queue) and the preview layer on the main thread. Apple documents this split as safe;
/// the preview only reads it.
extension AVCaptureSession: @retroactive @unchecked Sendable {}
