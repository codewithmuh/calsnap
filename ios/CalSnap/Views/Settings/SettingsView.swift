import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(MealStore.self) private var meals

    @State private var goal = 2000
    @State private var saving = false
    @State private var savedFlash = false
    @State private var showingLogin = false

    var body: some View {
        NavigationStack {
            Form {
                if auth.isAuthenticated {
                    Section("Account") {
                        LabeledContent("Email", value: auth.currentUser?.email ?? "—")
                    }
                } else {
                    Section {
                        Button {
                            showingLogin = true
                        } label: {
                            Label("Log in or create account", systemImage: "person.crop.circle")
                        }
                    } footer: {
                        Text("You're using CalSnap as a guest. Meals are stored on this device. Log in to sync them to an account.")
                    }
                }

                Section("Daily calorie goal") {
                    Stepper("\(goal) kcal", value: $goal, in: 1000...5000, step: 50)
                    Button {
                        save()
                    } label: {
                        HStack {
                            if saving { ProgressView() }
                            Text(savedFlash ? "Saved ✓" : "Save goal")
                        }
                    }
                    .disabled(saving || goal == currentGoal)
                }

                if auth.isAuthenticated {
                    Section {
                        Button("Log out", role: .destructive) {
                            logout()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { goal = currentGoal }
            .sheet(isPresented: $showingLogin) {
                AuthView()
                    .onDisappear { goal = currentGoal }
            }
        }
    }

    private var currentGoal: Int {
        auth.isAuthenticated ? (auth.currentUser?.dailyCalorieGoal ?? 2000) : meals.guestGoal
    }

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            if auth.isAuthenticated {
                if let updated = try? await APIClient.shared.updateGoal(goal) {
                    auth.applyUpdatedUser(updated)
                    await flashSaved()
                }
            } else {
                meals.setGuestGoal(goal)
                await flashSaved()
            }
        }
    }

    private func flashSaved() async {
        savedFlash = true
        try? await Task.sleep(for: .seconds(1.5))
        savedFlash = false
    }

    private func logout() {
        auth.logout()
        goal = currentGoal
        Task { await meals.reloadForGuest() }
    }
}
