//
//  GoogleFontsPackSource.swift
//  Cue Studio
//

import Foundation

/// The files from github.com/google/fonts at the commit the manifest pins (each file's `url`): the fonts exactly as Google
/// Fonts publishes them, under their licences. Downloading sends the iPhone's IP address to GitHub, nothing else (no account,
/// no words of the video).
nonisolated struct GoogleFontsPackSource: FontPackSource {
    var session: URLSession = .shared

    enum Failure: Error {
        case status(Int)
    }

    func data(for file: FontPack.File, progress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        var request = URLRequest(url: file.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.allowsExpensiveNetworkAccess = true
        let observer = ProgressObserver(report: progress)
        let (location, response) = try await session.download(for: request, delegate: observer)
        defer { try? FileManager.default.removeItem(at: location) }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw Failure.status(http.statusCode) }
        progress(1)
        return try Data(contentsOf: location)
    }

    /// Hears how far a download has come.
    private final class ProgressObserver: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        let report: @Sendable (Double) -> Void
        private var observation: NSKeyValueObservation?

        init(report: @escaping @Sendable (Double) -> Void) {
            self.report = report
        }

        func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
            let report = report
            observation = task.progress.observe(\.fractionCompleted) { progress, _ in report(progress.fractionCompleted) }
        }
    }
}
