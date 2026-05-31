import SwiftUI

/// Login / register, presented as a sheet. On success, any meals logged as a
/// guest are migrated to the account, then the sheet dismisses.
struct AuthView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(MealStore.self) private var meals
    @Environment(\.dismiss) private var dismiss

    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var goal = 2000
    @State private var migrating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 52))
                            .foregroundStyle(.tint)
                        Text(isRegistering ? "Create your account" : "Welcome back")
                            .font(.title2.bold())
                        Text("Log in to sync your meals across devices.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $password)
                            .textContentType(isRegistering ? .newPassword : .password)

                        if isRegistering {
                            Stepper("Daily goal: \(goal) kcal", value: $goal, in: 1000...5000, step: 50)
                                .font(.subheadline)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: submit) {
                        HStack {
                            if auth.isWorking || migrating { ProgressView().tint(.white) }
                            Text(migrating ? "Syncing your meals…"
                                 : (isRegistering ? "Create account" : "Log in"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .disabled(auth.isWorking || migrating || email.isEmpty || password.isEmpty)
                    .padding(.horizontal)

                    Button {
                        withAnimation { isRegistering.toggle() }
                    } label: {
                        Text(isRegistering
                             ? "Already have an account? Log in"
                             : "New here? Create an account")
                            .font(.footnote)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle(isRegistering ? "Sign up" : "Log in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Continue as guest") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(auth.isWorking || migrating)
    }

    private func submit() {
        Task {
            let ok: Bool
            if isRegistering {
                ok = await auth.register(email: email, password: password, goal: goal)
            } else {
                ok = await auth.login(email: email, password: password)
            }
            guard ok else { return }
            migrating = true
            await meals.migrateGuestMeals()
            migrating = false
            dismiss()
        }
    }
}
