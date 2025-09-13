import Foundation
import CoreData

/// A simple domain model for a note.
struct Note: Identifiable, Hashable {
    var id: Int
    var title: String
    var description: String
    var createdAt: Date
    var updatedAt: Date
    var creatorName: String
    var creatorUsername: String

    /// Explicit memberwise initializer so we can create Notes in code/previews
    init(id: Int, title: String, description: String, createdAt: Date, updatedAt: Date, creatorName: String, creatorUsername: String) {
        self.id = id
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.creatorName = creatorName
        self.creatorUsername = creatorUsername
    }

    /// Initialize a note from a Core Data entity.
    init(entity: NoteEntity) {
        self.id = Int(entity.id)
        self.title = entity.title ?? ""
        self.description = entity.noteDescription ?? ""
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
        self.creatorName = entity.creatorName ?? ""
        self.creatorUsername = entity.creatorUsername ?? ""
    }
}
