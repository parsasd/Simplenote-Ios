import SwiftUI

/// Displays the full details of a note along with edit and delete actions.
struct NoteDetailView: View {
    var note: Note
    @ObservedObject var notesVM: NoteListViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var showingEdit = false
    @State private var isDeleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(note.title)
                .font(.title).fontWeight(.bold)
            Text(note.description)
                .font(.body).foregroundColor(.secondary)

            HStack {
                Text("Updated: \(note.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote).foregroundColor(.secondary)
                Spacer()
                Text("by \(note.creatorUsername)")
                    .font(.footnote).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Note")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Edit") { showingEdit = true }
                Button(role: .destructive) { isDeleting = true } label: { Text("Delete") }
            }
        }
        .sheet(isPresented: $showingEdit) {
            // Pass the full note here as well
            AddEditNoteView(notesVM: notesVM, note: note)
        }
        .alert("Delete note?", isPresented: $isDeleting) {
            Button("Delete", role: .destructive) {
                Task {
                    await notesVM.deleteNote(note: note)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let stub = Note(
            id: 1,
            title: "Title",
            description: "Body",
            createdAt: .now,
            updatedAt: .now,
            creatorName: "",
            creatorUsername: "me"
        )
        return NavigationView {
            NoteDetailView(note: stub, notesVM: NoteListViewModel())
        }
    }
}
