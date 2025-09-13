import SwiftUI

/// View for registering a new user.  Uses AuthViewModel for network operations.
struct RegisterView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Register")
                    .font(.largeTitle)
                    .bold()

                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                TextField("First Name", text: $firstName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Last Name", text: $lastName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if case .loading = authVM.state {
                    ProgressView()
                }

                Button(action: {
                    Task {
                        await authVM.register(username: username, password: password, confirmPassword: confirmPassword, firstName: firstName, lastName: lastName, email: email)
                        // If registration succeeds, pop back to login
                        if case .idle = authVM.state {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }) {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(username.isEmpty || email.isEmpty || firstName.isEmpty || lastName.isEmpty || password.isEmpty || confirmPassword.isEmpty)

                if case .error(let message) = authVM.state {
                    Text(message)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView(authVM: AuthViewModel())
    }
}