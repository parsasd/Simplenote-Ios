import SwiftUI

/// Displays the current user's profile information and allows logout or changing password.
struct ProfileView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmNewPassword: String = ""
    @State private var changePasswordMessage: String?
    @State private var isChangingPassword: Bool = false
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 16) {
            if case .authenticated(let user) = authVM.state {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username: \(user.username)")
                    Text("Email: \(user.email)")
                    Text("First Name: \(user.firstName)")
                    Text("Last Name: \(user.lastName)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No user info available.")
            }

            Divider()
            Text("Change Password")
                .font(.headline)
            SecureField("Old Password", text: $oldPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("New Password", text: $newPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("Confirm New Password", text: $confirmNewPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            if let message = changePasswordMessage {
                Text(message)
                    .foregroundColor(.red)
            }
            Button(isChangingPassword ? "Changing..." : "Change Password") {
                Task {
                    await changePassword()
                }
            }
            .disabled(isChangingPassword || oldPassword.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)

            Spacer()
            Button("Logout") {
                authVM.logout()
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.red)
            .padding()
        }
        .padding()
        .navigationBarTitle("Profile", displayMode: .inline)
    }

    /// Attempts to change the user's password using the APIService.
    private func changePassword() async {
        guard newPassword == confirmNewPassword else {
            changePasswordMessage = "New passwords do not match"
            return
        }
        isChangingPassword = true
        changePasswordMessage = nil
        do {
            try await APIService.shared.changePassword(oldPassword: oldPassword, newPassword: newPassword)
            changePasswordMessage = "Password changed successfully"
            oldPassword = ""
            newPassword = ""
            confirmNewPassword = ""
        } catch {
            changePasswordMessage = "Failed to change password: \(error.localizedDescription)"
        }
        isChangingPassword = false
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView(authVM: AuthViewModel())
        }
    }
}