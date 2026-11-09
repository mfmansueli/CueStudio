//
//  TelemetryCollecting.swift
//  Cue Studio
//

import Foundation

/// Where "Help improve Cue" reaches the analytics and crash reports: whether they collect, and forgetting what waits on this iPhone to be sent.
/// Swappable so tests never touch Firebase.
protocol TelemetryCollecting: AnyObject {
    /// Analytics and crash reports collect only while this is on.
    func setCollecting(_ isOn: Bool)
    /// The crash reports not sent yet and the analytics kept for this install go; what comes later starts under a new id.
    func discardUnsent()
}
