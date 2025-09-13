import SwiftUI

/// The root view of the application.  It determines whether to show
/// authentication screens or the main notes interface based on the
/// authentication state.
struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        NavigationView {
            switch authVM.state {
            case .idle, .loading:
                ProgressView().onAppear {
                    Task { await authVM.loadUser() }
                }
            case .authenticated:
                NotesListView(authVM: authVM)
            case .unauthenticated:
                LoginView(authVM: authVM)
            case .error(let message):
                VStack {
                    Text(message)
                        .foregroundColor(.red)
                    Button("Retry") {
                        Task { await authVM.loadUser() }
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}