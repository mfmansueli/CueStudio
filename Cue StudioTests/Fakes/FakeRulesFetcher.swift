//
//  FakeRulesFetcher.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Returns a fixed rules file, or fails like a network error.
final class FakeRulesFetcher: PlatformRulesFetching {
    var result: Result<Data, Error>
    private(set) var requestedURL: URL?

    init(result: Result<Data, Error>) {
        self.result = result
    }

    func fetchRules(from url: URL) async throws -> Data {
        requestedURL = url
        return try result.get()
    }
}
