import Foundation

/// On-device persistence for guest-mode meals + goal. Local-only — no account.
/// Meals are stored as a JSON file in Documents (images base64-encoded inline,
/// which is plenty for a handful of meals); the goal lives in UserDefaults.
struct GuestStore {
    private let fileName = "guest_meals.json"
    private let goalKey = "guest_daily_goal"
    private let defaults = UserDefaults.standard

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    // MARK: - Meals

    func all() -> [LocalMeal] {
        guard let data = try? Data(contentsOf: fileURL),
              let meals = try? JSONDecoder().decode([LocalMeal].self, from: data) else {
            return []
        }
        return meals.sorted { $0.createdAt > $1.createdAt }
    }

    private func save(_ meals: [LocalMeal]) {
        if let data = try? JSONEncoder().encode(meals) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    @discardableResult
    func add(_ analysis: Analysis, mealType: MealType, imageData: Data?, note: String) -> LocalMeal {
        let meal = LocalMeal(analysis: analysis, mealType: mealType, imageData: imageData, note: note, createdAt: Date())
        var meals = all()
        meals.insert(meal, at: 0)
        save(meals)
        return meal
    }

    func delete(_ id: UUID) {
        save(all().filter { $0.id != id })
    }

    func clearMeals() {
        save([])
    }

    func todayItems() -> [MealItem] {
        let today = DateFormatter.todayUTCString()
        return all()
            .filter { DateFormatter.utcString(from: $0.createdAt) == today }
            .map(\.asItem)
    }

    /// Build a 7-day WeeklyStats from local meals (oldest -> newest).
    func weekly(goal: Int) -> WeeklyStats {
        let meals = all()
        var byDay: [String: (cal: Int, p: Int, c: Int, f: Int)] = [:]
        for m in meals {
            let key = DateFormatter.utcString(from: m.createdAt)
            var agg = byDay[key] ?? (0, 0, 0, 0)
            agg.cal += m.calories; agg.p += m.protein; agg.c += m.carbs; agg.f += m.fat
            byDay[key] = agg
        }

        var days: [DayStat] = []
        let cal = Calendar.current
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let key = DateFormatter.utcString(from: date)
            let agg = byDay[key] ?? (0, 0, 0, 0)
            days.append(DayStat(date: key, calories: agg.cal, protein: agg.p, carbs: agg.c, fat: agg.f))
        }
        return WeeklyStats(goal: goal, days: days)
    }

    // MARK: - Goal

    func loadGoal() -> Int {
        let value = defaults.integer(forKey: goalKey)
        return value == 0 ? 2000 : value
    }

    func saveGoal(_ goal: Int) {
        defaults.set(goal, forKey: goalKey)
    }
}
