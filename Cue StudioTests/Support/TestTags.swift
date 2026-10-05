//
//  TestTags.swift
//  Cue StudioTests
//

import Testing

/// Tags the test plans filter on (`TestPlans/`): the Fast plan skips them, the Full plan runs everything.
extension Tag {
    /// The suites inside `RealExports`: real encoding, the slowest and least steady part of the unit run.
    @Tag static var realExports: Self
}
