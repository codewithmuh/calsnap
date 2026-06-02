import SwiftUI

struct TodayView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(MealStore.self) private var meals

    @State private var showingSnap = false
    @State private var showingLogin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !auth.isAuthenticated {
                        guestBanner
                    }

                    CalorieRing(consumed: meals.consumedCalories, goal: meals.goal)
                        .padding(.top, 4)

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
            .sheet(isPresented: $showingSnap) { SnapFlowView() }
            .sheet(isPresented: $showingLogin) { AuthView() }
        }
    }

    private var guestBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("You're using CalSnap as a guest")
                    .font(.subheadline.weight(.semibold))
                Text("Meals are saved on this device. Log in to sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Log in") { showingLogin = true }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
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
        if meals.isLoading && meals.items.isEmpty {
            ProgressView().padding(.top, 40)
        } else if meals.items.isEmpty {
            ContentUnavailableView(
                "No meals yet",
                systemImage: "fork.knife",
                description: Text("Tap “Snap a meal” to log your first meal of the day.")
            )
            .padding(.top, 24)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("Today's meals")
                    .font(.headline)
                    .padding(.horizontal)
                ForEach(MealType.allCases) { type in
                    let group = meals.items.filter { $0.mealType == type }
                    if !group.isEmpty {
                        mealGroup(type, items: group)
                    }
                }
            }
        }
    }

    private func mealGroup(_ type: MealType, items: [MealItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(type.label, systemImage: type.icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(items.reduce(0) { $0 + $1.calories }) kcal")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            ForEach(items) { item in
                MealRow(item: item)
                    .padding(.horizontal)
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
    let item: MealItem
    @Environment(MealStore.self) private var meals

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.foodName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("P \(item.protein) · C \(item.carbs) · F \(item.fat)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(item.calories)")
                .font(.headline.monospacedDigit())
                + Text(" kcal").font(.caption).foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .swipeActions {
            Button(role: .destructive) {
                Task { await meals.delete(item) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await meals.delete(item) }
            } label: {
                Label("Delete meal", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = item.imageData, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let url = item.imageURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Color(.systemGray6)
            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
    }
}
