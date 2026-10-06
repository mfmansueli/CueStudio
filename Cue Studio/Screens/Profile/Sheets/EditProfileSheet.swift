//
//  EditProfileSheet.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// 9.1 · Edit Profile (large): Cancel and Done (off while the draft is invalid), the photo (96 pt) with "Edit Photo", one card with Name, Username and Creator
/// type, and "Shown on the universe cards you share." under it. Nothing reaches the profile until Done, which says "Profile updated".
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
                VStack(spacing: 0) {
                    EditProfilePhoto(draft: $draft, item: $photoItem).padding(.top, 14).padding(.bottom, 26)
                    VStack(spacing: 0) {
                        row("Name") {
                            TextField("Name", text: $draft.name)
                                .multilineTextAlignment(.trailing)
                                .textContentType(.name)
                                .accessibilityIdentifier("editProfile.nameField")
                        }
                        divider
                        row("Username") {
                            HStack(spacing: 6) {
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
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        divider
                        roleRow
                    }
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    footer.padding(.top, 8)
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

    // MARK: - Rows

    private func row<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 17)).foregroundStyle(Palette.ink).frame(width: 104, alignment: .leading)
            value().font(.system(size: 17)).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private var divider: some View {
        Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 16)
    }

    private var roleRow: some View {
        Menu {
            Picker("Creator type", selection: $draft.role) {
                Text("Not set").tag(CreatorRole?.none)
                ForEach(CreatorRole.allCases) { Text($0.creatorLabel).tag(CreatorRole?.some($0)) }
            }
        } label: {
            HStack(spacing: 12) {
                Text("Creator type").font(.system(size: 17)).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(draft.role?.creatorLabel ?? String(localized: "Not set")).font(.system(size: 17)).foregroundStyle(Palette.ink2)
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("editProfile.rolePicker")
    }

    @ViewBuilder
    private var footer: some View {
        Group {
            if let error = draft.handleError {
                Text(error).foregroundStyle(Palette.warnText).accessibilityIdentifier("editProfile.handleError")
            } else {
                Text("Shown on the universe cards you share.").foregroundStyle(Palette.ink2)
            }
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
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
