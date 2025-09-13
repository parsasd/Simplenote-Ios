import Foundation
import Combine

/// ViewModel responsible for user authentication and profile.
@MainActor
final class AuthViewModel: ObservableObject {
    enum AuthState {
        case idle
        case loading
        case authenticated(User)
        case unauthenticated
        case error(String)
    }

    @Published private(set) var state: AuthState = .idle

    /// Registers a new user.
    func register(username: String, password: String, confirmPassword: String, firstName: String, lastName: String, email: String) async {
        guard password == confirmPassword else {
            state = .error("Passwords do not match")
            return
        }
        state = .loading
        do {
            try await APIService.shared.register(username: username, password: password, firstName: firstName, lastName: lastName, email: email)
            state = .idle
        } catch {
            state = .error("Registration failed: \(error.localizedDescription)")
        }
    }

    /// Logs in the user.
    func login(username: String, password: String) async {
        state = .loading
        do {
            try await APIService.shared.login(username: username, password: password)
            let user = try await APIService.shared.getUserInfo()
            state = .authenticated(user)
        } catch {
            state = .error("Login failed: \(error.localizedDescription)")
        }
    }

    /// Fetch the current user from API (if logged in).
    func loadUser() async {
        state = .loading
        do {
            let user = try await APIService.shared.getUserInfo()
            state = .authenticated(user)
        } catch {
            state = .unauthenticated
        }
    }

    /// Logs out.
    func logout() {
        APIService.shared.logout()
        state = .unauthenticated
    }
}