import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        // Build the model programmatically
        let model = NSManagedObjectModel()

        let noteEntity = NSEntityDescription()
        noteEntity.name = "NoteEntity"
        noteEntity.managedObjectClassName = NSStringFromClass(NoteEntity.self)

        func makeAttr(_ name: String,
                      _ type: NSAttributeType,
                      optional: Bool = true,
                      defaultValue: Any? = nil) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            a.defaultValue = defaultValue
            return a
        }

        let id              = makeAttr("id", .integer64AttributeType, optional: false)
        let title           = makeAttr("title", .stringAttributeType)
        let noteDescription = makeAttr("noteDescription", .stringAttributeType)
        let createdAt       = makeAttr("createdAt", .dateAttributeType)
        let updatedAt       = makeAttr("updatedAt", .dateAttributeType)
        let creatorName     = makeAttr("creatorName", .stringAttributeType)
        let creatorUsername = makeAttr("creatorUsername", .stringAttributeType)
        let isSynced        = makeAttr("isSynced", .booleanAttributeType, optional: false, defaultValue: false)
        let softDeleted     = makeAttr("softDeleted", .booleanAttributeType, optional: false, defaultValue: false) // <- renamed

        noteEntity.properties = [
            id, title, noteDescription, createdAt, updatedAt,
            creatorName, creatorUsername, isSynced, softDeleted
        ]

        model.entities = [noteEntity]

        container = NSPersistentContainer(name: "SimpleNoteModel", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("CoreData error: \(error)") }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
