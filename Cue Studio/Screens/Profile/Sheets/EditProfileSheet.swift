//
//  EditProfileSheet.swift
//  Cue Studio
//

import SwiftUI

struct EditProfileSheet: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var profile = profile
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $profile.profile.name)
                        .textContentType(.name)
                        .accessibilityIdentifier("editProfile.nameField")
                    HStack(spacing: 2) {
                        Text("@").foregroundStyle(Palette.ink2)
                        TextField("handle", text: $profile.profile.handle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                    }
                } footer: {
                    Text("Shown only on this device.")
                }
            }
            .navigationTitle("Your profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) { EditProfileSheet() }
        .previewEnvironment()
}
#endif
