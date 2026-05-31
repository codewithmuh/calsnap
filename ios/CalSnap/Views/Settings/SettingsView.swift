import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth

    @State private var goal = 2000
    @State private var saving = false
    @State private var savedFlash = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Email", value: auth.currentUser?.email ?? "—")
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
                    .disabled(saving || goal == auth.currentUser?.dailyCalorieGoal)
                }

                Section {
                    Button("Log out", role: .destructive) {
                        auth.logout()
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { goal = auth.currentUser?.dailyCalorieGoal ?? 2000 }
        }
    }

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            if let updated = try? await APIClient.shared.updateGoal(goal) {
                auth.applyUpdatedUser(updated)
                savedFlash = true
                try? await Task.sleep(for: .seconds(1.5))
                savedFlash = false
            }
        }
    }
}
