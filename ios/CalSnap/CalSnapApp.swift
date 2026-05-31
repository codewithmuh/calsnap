import SwiftUI

@main
struct CalSnapApp: App {
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .tint(.accentColor)
        }
    }
}
