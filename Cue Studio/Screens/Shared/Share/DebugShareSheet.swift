//
//  DebugShareSheet.swift
//  Cue Studio
//

#if DEBUG
import SwiftUI

/// The stand-in for the system share sheet in UI tests: "Complete" is an activity that accepted the file, "Cancel" is the sheet dismissed.
struct DebugShareSheet: View {
    let onFinish: (ActivityResult) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(verbatim: "Share sheet (test)").font(.headline)
            Button { onFinish(.completed(activityType: "com.zhiliaoapp.musically.share")) } label: { Text(verbatim: "Complete") }
                .buttonStyle(.cuePrimary(.large))
                .accessibilityIdentifier("debug.share.complete")
            Button { onFinish(.cancelled) } label: { Text(verbatim: "Cancel") }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("debug.share.cancel")
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}
#endif
