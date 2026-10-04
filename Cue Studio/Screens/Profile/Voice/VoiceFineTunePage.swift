//
//  VoiceFineTunePage.swift
//  Cue Studio
//

import SwiftUI

/// Under My Cue Voice (9.3): the fine-tuning groups — how I sound, my phrases, who I talk to, my style and niche — that used
/// to sit on Profile. Everything is free and stays on the iPhone.
struct VoiceFineTunePage: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast
    @State private var isAddingPhrase = false
    @State private var newPhrase = ""

    var body: some View {
        List {
            CreatorVoiceSection(
                onAddPhrase: {
                    newPhrase = ""
                    isAddingPhrase = true
                }
            )
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .skyBackground()
        .navigationTitle("Fine-tune")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Add a phrase", isPresented: $isAddingPhrase) {
            TextField("Hey fam", text: $newPhrase)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let phrase = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
                if profile.addPhrase(phrase) { toast.show(String(localized: "Added “\(phrase)”")) }
            }
        } message: {
            Text("Something you always say. The AI weaves it into new scripts.")
        }
    }
}
