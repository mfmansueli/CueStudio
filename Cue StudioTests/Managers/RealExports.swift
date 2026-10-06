//
//  RealExports.swift
//  Cue StudioTests
//

import Testing

/// The suites that run the real export pipeline (AVFoundation's encoder on footage written for the test) live inside this one.
/// `.serialized` reaches every suite inside, so they take turns: side by side in the parallel run they starved each other's
/// encoder and one of them ran past its time limit, while each passes in seconds on its own. The rest of the suite still runs
/// in parallel around them. The Fast test plan leaves them out (`.realExports`).
@Suite("Real exports", .serialized, .tags(.realExports))
enum RealExports {}
