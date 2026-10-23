//
//  RealMedia.swift
//  Cue StudioTests
//

import Testing

/// The suites that run the editor on a real recording (footage written for the test), with the real editing service
/// (`TakeEditService`), player (`QuickEditPlayer`) and files, where the other editor suites use fakes: what AVFoundation does
/// with an edit is checked through the same steps a creator takes. `.serialized`, like `RealExports`, so their encoders
/// take turns. The Fast test plan leaves them out (`.realMedia`).
@Suite("Real media", .serialized, .tags(.realMedia))
enum RealMedia {}
