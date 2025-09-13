import Foundation

/// A service responsible for making network requests to the SimpleNote backend.
/// This service wraps all API endpoints and handles token storage.  It uses
/// async/await where possible and publishes errors via thrown exceptions.
final class APIService {
    static let shared = APIService()

    /// The base URL of the backend.  Change this to your server's domain.
    private let baseURL = URL(string: "http://192.168.8.162:8000")!

    /// Token keys used in UserDefaults.
    private struct TokenKeys {
        static let accessToken = "accessToken"
        static let refreshToken = "refreshToken"
    }

    private init() {}

    // MARK: - DTOs

    /// Internal representation of a note returned from the API.  Used for JSON decoding.
    private struct NoteResponse: Decodable {
        let id: Int
        let title: String
        let description: String
        let createdAt: Date
        let updatedAt: Date
        let creatorName: String
        let creatorUsername: String
    }

    /// Response wrapper for paginated notes.
    private struct NotesResponse: Decodable {
        let count: Int
        let next: String?
        let previous: String?
        let results: [NoteResponse]
    }

    // MARK: - Public API

    /// Registers a new user.
    func register(username: String, password: String, firstName: String, lastName: String, email: String) async throws {
        let url = baseURL.appendingPathComponent("api/auth/register/")
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "first_name": firstName,
            "last_name": lastName,
            "email": email
        ]
        _ = try await performRequest(url: url, method: "POST", body: body, requiresAuth: false)
    }

    /// Logs in and stores tokens.
    func login(username: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("api/auth/token/")
        let body: [String: Any] = ["username": username, "password": password]
        let data = try await performRequest(url: url, method: "POST", body: body, requiresAuth: false)
        let decoder = JSONDecoder()
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let access = json["access"] as? String,
           let refresh = json["refresh"] as? String {
            saveToken(access: access, refresh: refresh)
        } else {
            throw APIError.invalidResponse
        }
    }

    /// Refreshes the access token using the stored refresh token.
    func refreshToken() async throws {
        guard let refresh = getToken()?.refresh else { throw APIError.unauthorized }
        let url = baseURL.appendingPathComponent("api/auth/token/refresh/")
        let body: [String: Any] = ["refresh": refresh]
        let data = try await performRequest(url: url, method: "POST", body: body, requiresAuth: false)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let access = json["access"] as? String {
            saveToken(access: access, refresh: refresh)
        }
    }

    /// Fetches the authenticated user's info.
    func getUserInfo() async throws -> User {
        let url = baseURL.appendingPathComponent("api/auth/userinfo/")
        let data = try await performRequest(url: url, method: "GET", requiresAuth: true)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(User.self, from: data)
    }

    /// Changes password for the current user.
    func changePassword(oldPassword: String, newPassword: String) async throws {
        let url = baseURL.appendingPathComponent("api/auth/change-password/")
        let body: [String: Any] = [
            "old_password": oldPassword,
            "new_password": newPassword
        ]
        _ = try await performRequest(url: url, method: "POST", body: body, requiresAuth: true)
    }

    /// Retrieves a paginated list of notes.  Pass `page` to request subsequent pages.
    func getNotes(page: Int? = nil, query: String? = nil) async throws -> (notes: [Note], nextPage: Int?) {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(query == nil ? "api/notes/" : "api/notes/filter"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        if let page = page { queryItems.append(URLQueryItem(name: "page", value: String(page))) }
        if let page = query { // search uses title parameter for query; description search omitted
            queryItems.append(URLQueryItem(name: "title", value: page))
        }
        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems
        let url = urlComponents.url!
        let data = try await performRequest(url: url, method: "GET", requiresAuth: true)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(NotesResponse.self, from: data)
        let notes = result.results.map { nr in
            Note(id: nr.id, title: nr.title, description: nr.description, createdAt: nr.createdAt, updatedAt: nr.updatedAt, creatorName: nr.creatorName, creatorUsername: nr.creatorUsername)
        }
        // Parse next page number from the `next` URL
        let nextPage: Int? = {
            guard let next = result.next else { return nil }
            return URLComponents(string: next)?.queryItems?.first(where: { $0.name == "page" })?.value.flatMap { Int($0) }
        }()
        return (notes, nextPage)
    }

    /// Creates a new note on the server.
    func createNote(title: String, description: String) async throws -> Note {
        let url = baseURL.appendingPathComponent("api/notes/")
        let body: [String: Any] = ["title": title, "description": description]
        let data = try await performRequest(url: url, method: "POST", body: body, requiresAuth: true)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(NoteResponse.self, from: data)
        return Note(id: response.id, title: response.title, description: response.description, createdAt: response.createdAt, updatedAt: response.updatedAt, creatorName: response.creatorName, creatorUsername: response.creatorUsername)
    }

    /// Updates an existing note.
    func updateNote(id: Int, title: String, description: String) async throws -> Note {
        let url = baseURL.appendingPathComponent("api/notes/\(id)/")
        let body: [String: Any] = ["title": title, "description": description]
        let data = try await performRequest(url: url, method: "PUT", body: body, requiresAuth: true)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(NoteResponse.self, from: data)
        return Note(id: response.id, title: response.title, description: response.description, createdAt: response.createdAt, updatedAt: response.updatedAt, creatorName: response.creatorName, creatorUsername: response.creatorUsername)
    }

    /// Deletes a note from the server.
    func deleteNote(id: Int) async throws {
        let url = baseURL.appendingPathComponent("api/notes/\(id)/")
        _ = try await performRequest(url: url, method: "DELETE", requiresAuth: true)
    }

    /// Logs out by clearing stored tokens.
    func logout() {
        UserDefaults.standard.removeObject(forKey: TokenKeys.accessToken)
        UserDefaults.standard.removeObject(forKey: TokenKeys.refreshToken)
    }

    // MARK: - Private helpers

    private func performRequest(url: URL, method: String, body: [String: Any]? = nil, requiresAuth: Bool) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresAuth, let token = getToken()?.access {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            // Attempt to refresh token once
            try await refreshToken()
            return try await performRequest(url: url, method: method, body: body, requiresAuth: requiresAuth)
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    private func saveToken(access: String, refresh: String) {
        UserDefaults.standard.set(access, forKey: TokenKeys.accessToken)
        UserDefaults.standard.set(refresh, forKey: TokenKeys.refreshToken)
    }

    private func getToken() -> (access: String, refresh: String)? {
        guard let access = UserDefaults.standard.string(forKey: TokenKeys.accessToken),
              let refresh = UserDefaults.standard.string(forKey: TokenKeys.refreshToken) else {
            return nil
        }
        return (access, refresh)
    }
}

enum APIError: Error {
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int)
}
