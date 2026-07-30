import SwiftUI

struct AccountRootView: View {
    @EnvironmentObject private var accountStore: LocalAccountStore
    @EnvironmentObject private var warehouseStore: WarehouseMapStore

    var body: some View {
        Group {
            if let startupError = accountStore.startupError {
                LocalAccountFailureView(message: startupError)
            } else if accountStore.session == nil {
                LocalAccountAccessView(
                    defaultWorkspaceName: warehouseStore.plan.name
                )
            } else {
                ContentView()
            }
        }
        .onAppear {
            accountStore.synchronizeWorkspaceName(
                warehouseStore.plan.name
            )
        }
        .onChange(of: warehouseStore.plan.name) { _, newName in
            accountStore.synchronizeWorkspaceName(newName)
        }
        .onChange(
            of: accountStore.session?.workspace.name
        ) { _, newName in
            guard let newName,
                  warehouseStore.plan.name != newName else {
                return
            }
            warehouseStore.renameWarehouse(newName)
        }
    }
}

struct LocalAccountSettingsView: View {
    @EnvironmentObject private var accountStore: LocalAccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var workspaceName = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var passwordConfirmation = ""
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.title2)
                            .foregroundStyle(.cyan)
                            .frame(width: 46, height: 46)
                            .background(
                                Color.cyan.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 13)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Local account")
                                .font(.headline)
                            Text(
                                "SQL data and the signed-in session stay on this iPhone."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Profile") {
                    TextField("Your name", text: $fullName)
                        .textContentType(.name)

                    TextField(
                        "Warehouse or business",
                        text: $workspaceName
                    )

                    LabeledContent(
                        "Email",
                        value: accountStore.session?.account.email ?? ""
                    )
                    LabeledContent(
                        "Role",
                        value: accountStore.session?
                            .account.role.capitalized ?? "Owner"
                    )

                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save profile")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(
                        isSaving
                            || fullName.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                            || workspaceName.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                    )
                }

                Section {
                    SecureField(
                        "Current password",
                        text: $currentPassword
                    )
                    .textContentType(.password)

                    SecureField(
                        "New password",
                        text: $newPassword
                    )
                    .textContentType(.newPassword)

                    SecureField(
                        "Confirm new password",
                        text: $passwordConfirmation
                    )
                    .textContentType(.newPassword)

                    Button("Update password") {
                        updatePassword()
                    }
                    .disabled(
                        currentPassword.isEmpty
                            || newPassword.isEmpty
                            || passwordConfirmation.isEmpty
                    )
                } header: {
                    Text("Password")
                } footer: {
                    Text(
                        "Your password is stored in the iOS Keychain, not in SQLite."
                    )
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        signOut()
                    }
                    .frame(maxWidth: .infinity)
                } footer: {
                    Text(
                        "Signing out does not delete scans, maps, inventory, or this local account."
                    )
                }

                Section("Current limits") {
                    Label(
                        "No cross-device login or cloud sync yet",
                        systemImage: "icloud.slash"
                    )
                    Label(
                        "One local warehouse workspace on this iPhone",
                        systemImage: "building.2"
                    )
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            fullName = accountStore.session?.account.fullName ?? ""
            workspaceName = accountStore.session?.workspace.name ?? ""
        }
        .alert(
            "Account",
            isPresented: Binding(
                get: { errorMessage != nil || savedMessage != nil },
                set: { presented in
                    if !presented {
                        errorMessage = nil
                        savedMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
                savedMessage = nil
            }
        } message: {
            Text(errorMessage ?? savedMessage ?? "")
        }
    }

    private func saveProfile() {
        isSaving = true
        defer { isSaving = false }

        do {
            try accountStore.updateProfile(
                fullName: fullName,
                workspaceName: workspaceName
            )
            fullName = accountStore.session?.account.fullName ?? fullName
            workspaceName = accountStore.session?
                .workspace.name ?? workspaceName
            savedMessage = "Profile saved on this iPhone."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updatePassword() {
        do {
            try accountStore.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword,
                confirmation: passwordConfirmation
            )
            currentPassword = ""
            newPassword = ""
            passwordConfirmation = ""
            savedMessage = "Password updated in the iOS Keychain."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signOut() {
        do {
            try accountStore.signOut()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct LocalAccountAccessView: View {
    @EnvironmentObject private var accountStore: LocalAccountStore
    let defaultWorkspaceName: String
    @State private var workspaceName = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private var isCreating: Bool {
        !accountStore.hasLocalAccount
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.045, blue: 0.075),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    brandHeader
                    accountCard
                }
                .padding(22)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if workspaceName.isEmpty {
                workspaceName = defaultWorkspaceName == "My Warehouse"
                    ? ""
                    : defaultWorkspaceName
            }
        }
        .alert(
            "Unable to continue",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cube.transparent.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .frame(width: 50, height: 50)
                    .background(
                        Color.cyan.opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 15)
                    )

                Spacer()

                Label("LOCAL SQL", systemImage: "externaldrive.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Color.green.opacity(0.12),
                        in: Capsule()
                    )
            }

            Text(
                isCreating
                    ? "Create your warehouse account"
                    : "Welcome back"
            )
            .font(.largeTitle.bold())

            Text(
                isCreating
                    ? "Set up the owner account for this iPhone. Nothing is uploaded."
                    : "Sign in to the warehouse workspace stored on this iPhone."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var accountCard: some View {
        VStack(spacing: 16) {
            if isCreating {
                accountField(
                    title: "Warehouse or business",
                    icon: "building.2",
                    text: $workspaceName,
                    contentType: .organizationName
                )

                accountField(
                    title: "Your full name",
                    icon: "person",
                    text: $fullName,
                    contentType: .name
                )
            }

            accountField(
                title: "Email",
                icon: "envelope",
                text: $email,
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                capitalization: .never
            )

            secureAccountField(
                title: "Password",
                icon: "lock",
                text: $password,
                contentType: isCreating ? .newPassword : .password
            )

            if isCreating {
                secureAccountField(
                    title: "Confirm password",
                    icon: "checkmark.shield",
                    text: $passwordConfirmation,
                    contentType: .newPassword
                )
            }

            Button {
                submit()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(
                            systemName: isCreating
                                ? "arrow.right.circle.fill"
                                : "lock.open.fill"
                        )
                    }
                    Text(isCreating ? "Create local account" : "Sign in")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.black)
                .background(.cyan, in: RoundedRectangle(cornerRadius: 15))
            }
            .disabled(isSubmitting)

            Label(
                "Passwords live in the iOS Keychain—not the SQL database.",
                systemImage: "key.fill"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            Color.white.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.09))
        }
    }

    private func accountField(
        title: String,
        icon: String,
        text: Binding<String>,
        contentType: UITextContentType?,
        keyboardType: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .words
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
                .frame(width: 22)
            TextField(title, text: text)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(
                    keyboardType == .emailAddress
                )
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(
            Color.white.opacity(0.075),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    private func secureAccountField(
        title: String,
        icon: String,
        text: Binding<String>,
        contentType: UITextContentType?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
                .frame(width: 22)
            SecureField(title, text: text)
                .textContentType(contentType)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(
            Color.white.opacity(0.075),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    private func submit() {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            if isCreating {
                try accountStore.createOwner(
                    workspaceName: workspaceName,
                    fullName: fullName,
                    email: email,
                    password: password,
                    passwordConfirmation: passwordConfirmation
                )
            } else {
                try accountStore.signIn(
                    email: email,
                    password: password
                )
            }
            password = ""
            passwordConfirmation = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct LocalAccountFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(
                "Local account unavailable",
                systemImage: "externaldrive.badge.exclamationmark"
            )
        } description: {
            Text(message)
        } actions: {
            Text(
                "Your scans have not been deleted. Close and reopen the app after checking available iPhone storage."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}
