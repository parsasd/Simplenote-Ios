import Foundation

/// A simple user model for authenticated user information.
struct User: Identifiable, Codable, Hashable {
    var id: Int
    var username: String
    var email: String
    var firstName: String
    var lastName: String
}