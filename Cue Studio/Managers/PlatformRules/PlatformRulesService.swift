//
//  PlatformRulesService.swift
//  Cue Studio
//

import Foundation
import os

/// The platform rules in use. Starts from the copy in the bundle (or a newer cached download) and,
/// when `AppLinks.platformRules` is set, checks the web for a newer revision once per launch.
/// A download that is older, for another schema or incomplete is ignored.
@MainActor
@Observable
final class PlatformRulesService {
    private(set) var rules: PlatformRules

    private let cacheURL: URL?
    private let remoteURL: URL?
    private let fetcher: PlatformRulesFetching
    private let logger = Logger(subsystem: "studio.cue", category: "PlatformRules")

    init(
        bundled: PlatformRules = PlatformRulesService.bundledRules(),
        cacheURL: URL? = URL.applicationSupportDirectory.appending(path: "Library/PlatformRules.json"),
        remoteURL: URL? = AppLinks.platformRules,
        fetcher: PlatformRulesFetching = URLSessionRulesFetcher()
    ) {
        self.cacheURL = cacheURL
        self.remoteURL = remoteURL
        self.fetcher = fetcher
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let cached = try? PlatformRules.decode(data), cached.revision > bundled.revision {
            rules = cached
        } else {
            rules = bundled
        }
    }

    // MARK: - Reading

    func preset(for platform: Platform, monetizationGoals: Bool) -> PlatformPreset {
        rules.preset(for: platform, monetizationGoals: monetizationGoals)
    }

    // MARK: - Updating

    /// Looks for newer rules. Failures keep the current rules; the next launch tries again.
    func refresh() async {
        guard let remoteURL else { return }
        do {
            let data = try await fetcher.fetchRules(from: remoteURL)
            apply(downloaded: data)
        } catch {
            logger.notice("Platform rules not updated: \(error.localizedDescription)")
        }
    }

    /// Adopts a downloaded file when it is valid and newer, and keeps it for the next launches.
    func apply(downloaded data: Data) {
        do {
            let downloaded = try PlatformRules.decode(data)
            guard downloaded.revision > rules.revision else { return }
            rules = downloaded
            if let cacheURL {
                try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: cacheURL, options: .atomic)
            }
        } catch {
            logger.error("Ignored platform rules: \(String(describing: error))")
        }
    }

    // MARK: - Bundle

    /// The rules shipped with the app. A missing or broken bundled file is a build error, not a
    /// runtime condition, so it stops the app in every build.
    nonisolated static func bundledRules(in bundle: Bundle = .main) -> PlatformRules {
        guard let url = bundle.url(forResource: "PlatformRules", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { preconditionFailure("PlatformRules.json is missing from the app bundle") }
        do {
            return try PlatformRules.decode(data)
        } catch {
            preconditionFailure("PlatformRules.json is invalid: \(error)")
        }
    }
}
