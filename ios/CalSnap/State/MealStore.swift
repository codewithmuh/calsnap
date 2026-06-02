import Foundation
import Observation

@MainActor
@Observable
final class MealStore {
    private let auth: AuthStore
    private let guest = GuestStore()

    /// Today's meals (server when logged in, local when guest).
    var items: [MealItem] = []
    var weekly: WeeklyStats?
    var isLoading = false
    var errorMessage: String?

    /// Guest daily goal (logged-in goal comes from the account).
    private(set) var guestGoal: Int

    init(auth: AuthStore) {
        self.auth = auth
        self.guestGoal = guest.loadGoal()
    }

    private var isAuthed: Bool { auth.isAuthenticated }

    var goal: Int {
        isAuthed ? (auth.currentUser?.dailyCalorieGoal ?? 2000) : guestGoal
    }

    var consumedCalories: Int { items.reduce(0) { $0 + $1.calories } }
    var consumedProtein: Int { items.reduce(0) { $0 + $1.protein } }
    var consumedCarbs: Int { items.reduce(0) { $0 + $1.carbs } }
    var consumedFat: Int { items.reduce(0) { $0 + $1.fat } }

    // MARK: - Loading

    func loadToday() async {
        errorMessage = nil
        if isAuthed {
            isLoading = true
            defer { isLoading = false }
            do {
                let meals = try await APIClient.shared.meals(date: DateFormatter.todayUTCString())
                items = meals.map(\.asItem)
            } catch {
                setError(error)
            }
        } else {
            items = guest.todayItems()
        }
    }

    func loadWeekly() async {
        if isAuthed {
            do { weekly = try await APIClient.shared.weekly() }
            catch { setError(error) }
        } else {
            weekly = guest.weekly(goal: guestGoal)
        }
    }

    // MARK: - Mutations

    /// Save an analyzed meal — to the account if logged in, else to local guest storage.
    func addAnalyzed(_ analysis: Analysis, mealType: MealType, imageData: Data?, note: String) async {
        errorMessage = nil
        if isAuthed {
            do {
                let meal = try await APIClient.shared.createMeal(
                    analysis: analysis, mealType: mealType, imageData: imageData, note: note
                )
                items.insert(meal.asItem, at: 0)
            } catch {
                setError(error)
                return
            }
        } else {
            let local = guest.add(analysis, mealType: mealType, imageData: imageData, note: note)
            items.insert(local.asItem, at: 0)
        }
        await loadWeekly()
    }

    func delete(_ item: MealItem) async {
        let snapshot = items
        items.removeAll { $0.id == item.id }
        if let serverID = item.serverID {
            do { try await APIClient.shared.deleteMeal(id: serverID) }
            catch { items = snapshot; setError(error) }
        } else if let localID = item.localID {
            guest.delete(localID)
        }
        await loadWeekly()
    }

    func setGuestGoal(_ goal: Int) {
        guestGoal = goal
        guest.saveGoal(goal)
        if !isAuthed { weekly = guest.weekly(goal: goal) }
    }

    // MARK: - Guest -> account migration

    /// Upload locally-stored guest meals to the now-logged-in account, then
    /// clear local storage and reload from the server.
    func migrateGuestMeals() async {
        let locals = guest.all()
        for meal in locals.reversed() {  // oldest first to roughly preserve order
            _ = try? await APIClient.shared.createMeal(
                analysis: meal.analysis, mealType: meal.mealType,
                imageData: meal.imageData, note: meal.note
            )
        }
        guest.clearMeals()
        await loadToday()
        await loadWeekly()
    }

    /// After logout, drop back to the local guest view.
    func reloadForGuest() async {
        await loadToday()
        await loadWeekly()
    }

    // MARK: - Helpers

    private func setError(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
