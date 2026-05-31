import SwiftUI

struct TodayView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(MealStore.self) private var meals

    @State private var showingSnap = false

    private var goal: Int { auth.currentUser?.dailyCalorieGoal ?? 2000 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CalorieRing(consumed: meals.consumedCalories, goal: goal)
                        .padding(.top, 8)

                    MacroSummary(
                        protein: meals.consumedProtein,
                        carbs: meals.consumedCarbs,
                        fat: meals.consumedFat
                    )
                    .padding(.horizontal)

                    snapButton

                    mealsSection
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Today")
            .refreshable { await meals.loadToday() }
            .task { await meals.loadToday() }
            .sheet(isPresented: $showingSnap) {
                SnapFlowView()
            }
        }
    }

    private var snapButton: some View {
        Button {
            showingSnap = true
        } label: {
            Label("Snap a meal", systemImage: "camera.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var mealsSection: some View {
        if meals.isLoading && meals.todayMeals.isEmpty {
            ProgressView().padding(.top, 40)
        } else if meals.todayMeals.isEmpty {
            ContentUnavailableView(
                "No meals yet",
                systemImage: "fork.knife",
                description: Text("Tap “Snap a meal” to log your first meal of the day.")
            )
            .padding(.top, 24)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's meals")
                    .font(.headline)
                    .padding(.horizontal)
                ForEach(meals.todayMeals) { meal in
                    MealRow(meal: meal)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct MacroSummary: View {
    let protein: Int
    let carbs: Int
    let fat: Int

    var body: some View {
        HStack(spacing: 12) {
            macro("Protein", protein, .blue)
            macro("Carbs", carbs, .orange)
            macro("Fat", fat, .purple)
        }
    }

    private func macro(_ name: String, _ grams: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(grams)g").font(.headline).foregroundStyle(color)
            Text(name).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MealRow: View {
    let meal: Meal
    @Environment(MealStore.self) private var meals

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: meal.imageUrl.flatMap(URL.init)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Color(.systemGray6)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.foodName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("P \(meal.protein) · C \(meal.carbs) · F \(meal.fat)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(meal.calories)")
                .font(.headline.monospacedDigit())
                + Text(" kcal").font(.caption).foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .swipeActions {
            Button(role: .destructive) {
                Task { await meals.delete(meal) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await meals.delete(meal) }
            } label: {
                Label("Delete meal", systemImage: "trash")
            }
        }
    }
}
