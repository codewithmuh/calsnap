import Foundation
import Observation

@MainActor
@Observable
final class AuthStore {
    var currentUser: AuthUser?
    var isAuthenticated = false
    var isWorking = false
    var errorMessage: String?

    init() {
        // If we already have a token from a previous session, go straight in
        // and refresh the profile in the background.
        if Keychain.accessToken != nil {
            isAuthenticated = true
            Task { await refreshProfile() }
        }
    }

    @discardableResult
    func login(email: String, password: String) async -> Bool {
        await run {
            let res = try await APIClient.shared.login(email: email, password: password)
            self.persist(res)
        }
    }

    @discardableResult
    func register(email: String, password: String, goal: Int) async -> Bool {
        await run {
            let res = try await APIClient.shared.register(email: email, password: password, goal: goal)
            self.persist(res)
        }
    }

    func logout() {
        Keychain.clear()
        currentUser = nil
        isAuthenticated = false
    }

    func refreshProfile() async {
        do {
            currentUser = try await APIClient.shared.me()
        } catch APIError.unauthorized {
            // Token is stale/invalid (e.g. server DB was reset) — drop back to guest
            // instead of sitting in a broken "logged in" state.
            logout()
        } catch {
            // Transient error — keep the session; the user can retry.
        }
    }

    func applyUpdatedUser(_ user: AuthUser) {
        currentUser = user
    }

    // MARK: - Helpers

    private func persist(_ res: AuthResponse) {
        Keychain.accessToken = res.tokens.access
        Keychain.refreshToken = res.tokens.refresh
        currentUser = res.user
        isAuthenticated = true
    }

    @discardableResult
    private func run(_ work: @escaping () async throws -> Void) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await work()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}
