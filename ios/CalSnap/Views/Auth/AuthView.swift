import SwiftUI

struct AuthView: View {
    @Environment(AuthStore.self) private var auth

    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var goal = 2000

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.accentColor.opacity(0.25), Color(.systemBackground)],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                        Text("CalSnap")
                            .font(.largeTitle.bold())
                        Text("Snap your meal, AI counts the calories.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)

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
                            if auth.isWorking { ProgressView().tint(.white) }
                            Text(isRegistering ? "Create account" : "Log in")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .disabled(auth.isWorking || email.isEmpty || password.isEmpty)
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
        }
    }

    private func submit() {
        Task {
            if isRegistering {
                await auth.register(email: email, password: password, goal: goal)
            } else {
                await auth.login(email: email, password: password)
            }
        }
    }
}
