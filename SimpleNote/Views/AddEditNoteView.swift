import SwiftUI

/// View for creating or editing a note.  If `note` is nil, a new note will be created.
struct AddEditNoteView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var notesVM: NoteListViewModel
    var note: Note?

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(header: Text("Title")) {
                TextField("Title", text: $title)
            }
            Section(header: Text("Description")) {
                TextEditor(text: $description)
                    .frame(minHeight: 150)
            }
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationBarTitle(note == nil ? "New Note" : "Edit Note", displayMode: .inline)
        .navigationBarItems(leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() }, trailing: Button(isSaving ? "Saving..." : "Save") {
            Task {
                await save()
            }
        }.disabled(isSaving || title.isEmpty || description.isEmpty))
        .onAppear {
            if let note = note {
                title = note.title
                description = note.description
            }
        }
    }

    /// Saves the note by creating or updating.  Dismisses on success.
    private func save() async {
        isSaving = true
        errorMessage = nil
        if let existing = note {
            await notesVM.updateNote(note: existing, newTitle: title, newDescription: description)
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        } else {
            await notesVM.createNote(title: title, description: description)
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct AddEditNoteView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AddEditNoteView(notesVM: NoteListViewModel(), note: nil)
        }
    }
}