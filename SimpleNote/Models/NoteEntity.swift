import Foundation
import CoreData

@objc(NoteEntity)
public class NoteEntity: NSManagedObject {
    /// Convenience typed request that does NOT shadow the inherited fetchRequest().
    @nonobjc public class func fetchAllRequest() -> NSFetchRequest<NoteEntity> {
        NSFetchRequest<NoteEntity>(entityName: "NoteEntity")
    }

    @NSManaged public var id: Int64
    @NSManaged public var title: String?
    @NSManaged public var noteDescription: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var creatorName: String?
    @NSManaged public var creatorUsername: String?
    @NSManaged public var isSynced: Bool
    @NSManaged public var softDeleted: Bool   // <- renamed from isDeleted
}

extension NoteEntity: Identifiable {}
