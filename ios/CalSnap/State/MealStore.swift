import Foundation
import Observation

@MainActor
@Observable
final class MealStore {
    var todayMeals: [Meal] = []
    var weekly: WeeklyStats?
    var isLoading = false
    var errorMessage: String?

    var consumedCalories: Int {
        todayMeals.reduce(0) { $0 + $1.calories }
    }

    var consumedProtein: Int { todayMeals.reduce(0) { $0 + $1.protein } }
    var consumedCarbs: Int { todayMeals.reduce(0) { $0 + $1.carbs } }
    var consumedFat: Int { todayMeals.reduce(0) { $0 + $1.fat } }

    func loadToday() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            todayMeals = try await APIClient.shared.meals(date: DateFormatter.todayUTCString())
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadWeekly() async {
        do {
            weekly = try await APIClient.shared.weekly()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Called after a successful Claude analysis + save. Inserts at the top so the
    /// list and ring update immediately.
    func add(_ meal: Meal) {
        todayMeals.insert(meal, at: 0)
    }

    func delete(_ meal: Meal) async {
        let snapshot = todayMeals
        todayMeals.removeAll { $0.id == meal.id }
        do {
            try await APIClient.shared.deleteMeal(id: meal.id)
        } catch {
            // restore on failure
            todayMeals = snapshot
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
