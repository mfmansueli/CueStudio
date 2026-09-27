//
//  URLSessionRulesFetcher.swift
//  Cue Studio
//

import Foundation

/// Fetches the rules file over HTTPS. The file is a static JSON document (no backend, no account).
struct URLSessionRulesFetcher: PlatformRulesFetching {
    enum FetchError: Error {
        case badResponse
    }

    func fetchRules(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FetchError.badResponse
        }
        return data
    }
}
