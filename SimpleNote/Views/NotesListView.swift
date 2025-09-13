import SwiftUI

/// Displays a paginated list of notes with search, add, edit and delete functionality.
struct NotesListView: View {
    @ObservedObject var authVM: AuthViewModel
    @StateObject private var notesVM = NoteListViewModel()

    @State private var searchText: String = ""
    @State private var showingAddEdit: Bool = false
    @State private var editNote: Note? = nil
    @State private var showingProfile: Bool = false

    var body: some View {
        VStack {
            // Search bar
            HStack {
                TextField("Search", text: $searchText)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .onChange(of: searchText) { newValue in
                        Task {
                            await notesVM.searchNotes(query: newValue)
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        Task { await notesVM.searchNotes(query: "") }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding([.horizontal, .top])

            if notesVM.isLoading && notesVM.notes.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = notesVM.errorMessage {
                Spacer()
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                Button("Retry") {
                    Task { await notesVM.refreshNotes() }
                }
                Spacer()
            } else if notesVM.notes.isEmpty {
                Spacer()
                Text("No notes found")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(notesVM.notes, id: \ .self) { note in
                        NavigationLink(destination: NoteDetailView(note: note, notesVM: notesVM)) {
                            VStack(alignment: .leading) {
                                Text(note.title)
                                    .font(.headline)
                                Text(note.description)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                                Text("Updated at \(formattedDate(note.updatedAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onAppear {
                            Task { await notesVM.loadMoreNotesIfNeeded(currentNote: note) }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await notesVM.deleteNote(note: note) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editNote = note
                                showingAddEdit = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await notesVM.refreshNotes()
                }
            }
        }
        .navigationBarTitle("Notes")
        .navigationBarItems(
            leading: Button(action: { showingProfile = true }) {
                Image(systemName: "person.circle")
            },
            trailing: Button(action: {
                editNote = nil
                showingAddEdit = true
            }) {
                Image(systemName: "plus")
            }
        )
        .sheet(isPresented: $showingAddEdit) {
            NavigationView {
                AddEditNoteView(notesVM: notesVM, note: editNote)
            }
        }
        .sheet(isPresented: $showingProfile) {
            NavigationView {
                ProfileView(authVM: authVM)
            }
        }
        .onAppear {
            // Load user if not authenticated
            if case .authenticated = authVM.state {
                // Already authenticated
            } else {
                Task { await authVM.loadUser() }
            }
        }
    }

    /// Formats a date into a human‑readable string.
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct NotesListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotesListView(authVM: AuthViewModel())
        }
    }
}