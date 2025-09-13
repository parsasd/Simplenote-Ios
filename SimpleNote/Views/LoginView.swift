import SwiftUI

/// View for logging in a user.  Expects an AuthViewModel to handle authentication.
struct LoginView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showRegister: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In")
                .font(.largeTitle)
                .bold()

            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if case .loading = authVM.state {
                ProgressView()
            }

            Button(action: {
                Task {
                    await authVM.login(username: username, password: password)
                }
            }) {
                Text("Log In")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(username.isEmpty || password.isEmpty)

            if case .error(let message) = authVM.state {
                Text(message)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Text("Don't have an account?")
                Button("Register") {
                    showRegister = true
                }
            }
            .padding(.top)
            .foregroundColor(.blue)

            NavigationLink(
                destination: RegisterView(authVM: authVM),
                isActive: $showRegister
            ) { EmptyView() }
        }
        .padding()
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(authVM: AuthViewModel())
    }
}