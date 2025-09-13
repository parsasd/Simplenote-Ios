import Foundation
import Combine
import CoreData

/// ViewModel that handles listing, refreshing and searching notes.
@MainActor
final class NoteListViewModel: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var currentPage: Int = 1
    private var hasMorePages: Bool = true
    private var currentQuery: String?

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.container.viewContext) {
        self.context = context
        Task {
            await loadNotesFromLocal(query: nil)
            await refreshNotes()
        }
    }

    /// Loads notes from the local Core Data store.
    func loadNotesFromLocal(query: String?) async {
        currentQuery = query
        // Create a typed fetch request for the NoteEntity entity.
        let request: NSFetchRequest<NoteEntity> = NSFetchRequest<NoteEntity>(entityName: "NoteEntity")
        // Filter by query
        if let q = query, !q.isEmpty {
            request.predicate = NSPredicate(format: "(title CONTAINS[cd] %@) OR (noteDescription CONTAINS[cd] %@)", q, q)
        } else {
            request.predicate = NSPredicate(format: "softDeleted == NO")
        }
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        do {
            let results = try context.fetch(request)
            self.notes = results.map { Note(entity: $0) }
        } catch {
            self.errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }
    }

    /// Refreshes notes by syncing local unsynced notes and downloading all pages from the server.
    func refreshNotes() async {
        isLoading = true
        errorMessage = nil
        do {
            // Reset pagination
            currentPage = 1
            hasMorePages = true
            // First, synchronize any locally created/updated/deleted notes with the server
            try await syncUnsyncedNotes()
            // Then download the first page from the server, replacing existing notes
            try await downloadNextPage(reset: true)
        } catch {
            self.errorMessage = "Refresh failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Offline CRUD

    /// Creates a new note.  Tries to create on the server; if offline or fails, stores locally as unsynced.
    func createNote(title: String, description: String) async {
        do {
            let note = try await APIService.shared.createNote(title: title, description: description)
            // Save remote note locally
            let entity = NoteEntity(context: context)
            entity.id = Int64(note.id)
            entity.title = note.title
            entity.noteDescription = note.description
            entity.createdAt = note.createdAt
            entity.updatedAt = note.updatedAt
            entity.creatorName = note.creatorName
            entity.creatorUsername = note.creatorUsername
            entity.isSynced = true
            entity.softDeleted = false
            try context.save()
            await loadNotesFromLocal(query: currentQuery)
        } catch {
            // Offline: create local note with negative ID and mark unsynced
            let entity = NoteEntity(context: context)
            entity.id = Int64(generateLocalId())
            entity.title = title
            entity.noteDescription = description
            let now = Date()
            entity.createdAt = now
            entity.updatedAt = now
            entity.creatorName = ""
            entity.creatorUsername = ""
            entity.isSynced = false
            entity.softDeleted = false
            do {
                try context.save()
                await loadNotesFromLocal(query: currentQuery)
            } catch {
                self.errorMessage = "Failed to save note locally: \(error.localizedDescription)"
            }
        }
    }

    /// Updates an existing note.  If offline or fails, updates locally and marks unsynced.
    func updateNote(note: Note, newTitle: String, newDescription: String) async {
        do {
            // If note has a positive ID, attempt remote update
            if note.id > 0 {
                let updated = try await APIService.shared.updateNote(id: note.id, title: newTitle, description: newDescription)
                if let entity = fetchNoteEntity(by: note.id) {
                    entity.title = updated.title
                    entity.noteDescription = updated.description
                    entity.updatedAt = updated.updatedAt
                    entity.isSynced = true
                    entity.softDeleted = false
                    try context.save()
                    await loadNotesFromLocal(query: currentQuery)
                    return
                }
            }
            // If remote update fails or note id <= 0, update locally and mark unsynced
            if let entity = fetchNoteEntity(by: note.id) {
                entity.title = newTitle
                entity.noteDescription = newDescription
                entity.updatedAt = Date()
                entity.isSynced = false
                try context.save()
                await loadNotesFromLocal(query: currentQuery)
            }
        } catch {
            // On error, mark local note as unsynced
            if let entity = fetchNoteEntity(by: note.id) {
                entity.title = newTitle
                entity.noteDescription = newDescription
                entity.updatedAt = Date()
                entity.isSynced = false
                do {
                    try context.save()
                } catch {}
            }
            await loadNotesFromLocal(query: currentQuery)
        }
    }

    /// Deletes a note.  If offline, mark as deleted and unsynced.
    func deleteNote(note: Note) async {
        do {
            if note.id > 0 {
                try await APIService.shared.deleteNote(id: note.id)
                if let entity = fetchNoteEntity(by: note.id) {
                    context.delete(entity)
                    try context.save()
                }
                await loadNotesFromLocal(query: currentQuery)
            } else {
                // Local only note; just delete
                if let entity = fetchNoteEntity(by: note.id) {
                    context.delete(entity)
                    try context.save()
                    await loadNotesFromLocal(query: currentQuery)
                }
            }
        } catch {
            // Mark as deleted locally; will sync later
            if let entity = fetchNoteEntity(by: note.id) {
                entity.softDeleted = true
                entity.isSynced = false
                entity.updatedAt = Date()
                do {
                    try context.save()
                } catch {}
            }
            await loadNotesFromLocal(query: currentQuery)
        }
    }

    // MARK: - Sync unsynced notes

    /// Synchronize local unsynced notes with the server.  Handles create, update and delete operations.
    private func syncUnsyncedNotes() async throws {
        // Fetch all unsynced notes
        let fetchRequest: NSFetchRequest<NoteEntity> = NSFetchRequest(entityName: "NoteEntity")
        fetchRequest.predicate = NSPredicate(format: "isSynced == NO")
        let unsynced = try context.fetch(fetchRequest)
        for entity in unsynced {
            // If the note is marked as deleted
            if entity.softDeleted {
                if entity.id > 0 {
                    // Delete remote note
                    do {
                        try await APIService.shared.deleteNote(id: Int(entity.id))
                    } catch {
                        // skip deletion on failure; will try next sync
                        continue
                    }
                }
                context.delete(entity)
            } else {
                if entity.id > 0 {
                    // Update remote
                    do {
                        let updated = try await APIService.shared.updateNote(id: Int(entity.id), title: entity.title ?? "", description: entity.noteDescription ?? "")
                        entity.title = updated.title
                        entity.noteDescription = updated.description
                        entity.createdAt = updated.createdAt
                        entity.updatedAt = updated.updatedAt
                        entity.creatorName = updated.creatorName
                        entity.creatorUsername = updated.creatorUsername
                        entity.isSynced = true
                    } catch {
                        // keep entity unsynced for next sync attempt
                        continue
                    }
                } else {
                    // Create remote; local id <= 0
                    do {
                        let created = try await APIService.shared.createNote(title: entity.title ?? "", description: entity.noteDescription ?? "")
                        // Remove old local unsynced entity
                        context.delete(entity)
                        // Insert new synced entity
                        let newEntity = NoteEntity(context: context)
                        newEntity.id = Int64(created.id)
                        newEntity.title = created.title
                        newEntity.noteDescription = created.description
                        newEntity.createdAt = created.createdAt
                        newEntity.updatedAt = created.updatedAt
                        newEntity.creatorName = created.creatorName
                        newEntity.creatorUsername = created.creatorUsername
                        newEntity.isSynced = true
                        newEntity.softDeleted = false
                    } catch {
                        continue
                    }
                }
            }
        }
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Helper

    /// Generate a unique negative ID for new unsynced notes.
    private func generateLocalId() -> Int {
        return -Int.random(in: 1...Int.max)
    }

    /// Fetches a NoteEntity by ID (Int), including unsynced ones.
    private func fetchNoteEntity(by id: Int) -> NoteEntity? {
        let request: NSFetchRequest<NoteEntity> = NSFetchRequest(entityName: "NoteEntity")
        request.predicate = NSPredicate(format: "id == %d", id)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// Loads the next page from the server and stores notes locally.
    func loadMoreNotesIfNeeded(currentNote: Note) async {
        guard hasMorePages, let last = notes.last, last.id == currentNote.id else { return }
        do {
            try await downloadNextPage(reset: false)
        } catch {
            self.errorMessage = "Failed to load more: \(error.localizedDescription)"
        }
    }

    /// Internal helper to download the next page.  When reset is true, existing Core Data entries are removed.
    private func downloadNextPage(reset: Bool) async throws {
        if reset {
            // Remove existing notes only if not unsynced
            let fetchRequest: NSFetchRequest<NoteEntity> = NSFetchRequest(entityName: "NoteEntity")
            fetchRequest.predicate = NSPredicate(format: "softDeleted == NO")
            let results = try context.fetch(fetchRequest)
            for entity in results {
                context.delete(entity)
            }
            try context.save()
        }
        let query = currentQuery
        let (fetchedNotes, nextPage) = try await APIService.shared.getNotes(page: currentPage, query: query)
        // Save to Core Data
        for note in fetchedNotes {
            let entity = NoteEntity(context: context)
            entity.id = Int64(note.id)
            entity.title = note.title
            entity.noteDescription = note.description
            entity.createdAt = note.createdAt
            entity.updatedAt = note.updatedAt
            entity.creatorName = note.creatorName
            entity.creatorUsername = note.creatorUsername
            entity.isSynced = true
            entity.softDeleted = false
        }
        try context.save()
        // Update page info
        if let next = nextPage {
            currentPage = next
            hasMorePages = true
        } else {
            hasMorePages = false
        }
        await loadNotesFromLocal(query: query)
    }

    /// Searches notes locally and resets pagination.
    func searchNotes(query: String) async {
        await loadNotesFromLocal(query: query)
        currentPage = 1
        hasMorePages = true
        currentQuery = query
    }
}
