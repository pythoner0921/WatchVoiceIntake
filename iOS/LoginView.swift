import SwiftUI

// Shown once (until the Keychain token expires/is cleared) — this app has
// exactly one user, its own owner, so there's no signup flow here, just
// the same email/password already used on researchos.shuyinlab.com.
struct LoginView: View {
    @ObservedObject var authSession = AuthSession.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("登录 Research OS").font(.title2).bold()
            TextField("邮箱", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(.roundedBorder)
            SecureField("密码", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
            Button {
                login()
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("登录").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isLoading)
        }
        .padding()
    }

    private func login() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authSession.login(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
