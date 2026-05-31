import SwiftUI

@main
struct CalSnapApp: App {
    @State private var auth: AuthStore
    @State private var meals: MealStore

    init() {
        let auth = AuthStore()
        _auth = State(initialValue: auth)
        _meals = State(initialValue: MealStore(auth: auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(meals)
                .tint(.accentColor)
        }
    }
}
