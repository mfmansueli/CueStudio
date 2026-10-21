//
//  EditProfileSheet.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// 9.1 · Edit Profile (large; owner's redesign, 21/10/2026): Cancel and Done (off only while something typed doesn't fit; everything here
/// is optional), "how you appear" on top (the card of the shared universe, live, with the photo's camera badge: `EditProfilePhoto`), then
/// You (name and username, the same alignment, a ✓ when the username fits), What you make (`CreatorTypePicker`, with their own type),
/// When you create (`EditProfilePreferences`) and the account. Nothing reaches the profile until Done, which says "Profile updated".
struct EditProfileSheet: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ProfileDraft(CreatorProfile())
    @State private var hasLoaded = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EditProfilePhoto(draft: $draft, item: $photoItem).padding(.top, 8)
                    Text("The card on the universe you share. Everything here is optional.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .padding(.horizontal, Metrics.textGutter)
                        .padding(.top, 8)
                    sectionTitle(String(localized: "You"))
                    identity
                    footer.padding(.top, 8)
                    sectionTitle(String(localized: "What you make"))
                    CreatorTypePicker(draft: $draft)
                    sectionTitle(String(localized: "When you create"))
                    EditProfilePreferences(draft: $draft)
                    sectionTitle(String(localized: "Account"))
                    EditProfileAccount { name in if draft.name.isEmpty { draft.name = name } }
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("editProfile.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save).disabled(!draft.isValid).accessibilityIdentifier("editProfile.doneButton")
                }
            }
        }
        .tint(Palette.ink)
        .presentationDetents([.large])
        .presentationBackground(Palette.sheetNight)
        .interactiveDismissDisabled(isEdited)
        .onAppear {
            guard !hasLoaded else { return }
            draft = ProfileDraft(profile.profile)
            hasLoaded = true
        }
    }

    // MARK: - You

    /// Name and username, their fields starting at the same place; the username shows a ✓ once it fits, the name its count near the end.
    private var identity: some View {
        VStack(spacing: 0) {
            row("Name") {
                TextField("Your name", text: $draft.name)
                    .textContentType(.name)
                    .accessibilityIdentifier("editProfile.nameField")
                if draft.trimmedName.count > ProfileDraft.nameLimit.upperBound - 10 {
                    Text(verbatim: "\(draft.trimmedName.count)/\(ProfileDraft.nameLimit.upperBound)")
                        .font(.caption)
                        .foregroundStyle(draft.isNameValid ? Palette.ink2 : Palette.warnText)
                        .monospacedDigit()
                }
            }
            divider
            row("Username") {
                Text(verbatim: "@").foregroundStyle(Palette.ink2)
                TextField("username", text: $draft.handle)
                    // The field shows what is kept: typed capitals and spaces are replaced as they arrive (a binding that cleans in its
                    // setter leaves the typed text on screen, and the username kept differs from the one shown).
                    .onChange(of: draft.handle) { _, typed in
                        let kept = ProfileDraft.sanitized(typed)
                        if kept != typed { draft.handle = kept }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .accessibilityIdentifier("editProfile.handleField")
                if !draft.handle.isEmpty, draft.isHandleValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.successText)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel(Text("Valid"))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draft.isHandleValid && !draft.handle.isEmpty)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
    }

    private func row<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 8) {
            Text(title).foregroundStyle(Palette.ink).frame(width: 96, alignment: .leading)
            value()
        }
        .font(.system(size: 17))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 26, leading: Metrics.textGutter, bottom: 8, trailing: Metrics.textGutter))
            .accessibilityAddTraits(.isHeader)
    }

    private var divider: some View {
        Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 16)
    }

    @ViewBuilder
    private var footer: some View {
        if let error = draft.nameError ?? draft.handleError {
            Text(error)
                .font(.footnote)
                .foregroundStyle(Palette.warnText)
                .padding(.horizontal, Metrics.textGutter)
                .accessibilityIdentifier("editProfile.handleError")
        }
    }

    // MARK: - Draft

    /// Something was typed or chosen: swiping the sheet away would lose it.
    private var isEdited: Bool { hasLoaded && draft != ProfileDraft(profile.profile) }

    private func save() {
        guard draft.isValid else { return }
        profile.profile = draft.applied(to: profile.profile)
        toast.show(String(localized: "Profile updated"))
        dismiss()
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) { EditProfileSheet() }
        .previewEnvironment()
}
#endif
