import Foundation
import Security

// Minimal auth: log in once with the same email/password used on
// researchos.shuyinlab.com, store the JWT in Keychain (survives app
// relaunch, and unlike UserDefaults isn't plaintext-on-disk) — matches
// the 30-day expiry the server's authRequired middleware already uses
// for every other client, so this only needs re-login roughly monthly.
final class AuthSession: ObservableObject {
    static let shared = AuthSession()
    static let apiBaseURL = URL(string: "https://researchos.shuyinlab.com")!

    private static let service = "com.shuyinlab.watchvoiceintake"
    private static let account = "authToken"

    @Published private(set) var isLoggedIn: Bool

    private init() {
        isLoggedIn = Self.readToken() != nil
    }

    var token: String? { Self.readToken() }

    func login(email: String, password: String) async throws {
        var request = URLRequest(url: Self.apiBaseURL.appendingPathComponent("api/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["message"]
            throw AuthError.failed(message ?? "登录失败，请检查邮箱和密码")
        }
        struct LoginResponse: Decodable { let token: String }
        let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
        Self.writeToken(decoded.token)
        await MainActor.run { self.isLoggedIn = true }
    }

    func logout() {
        Self.deleteToken()
        isLoggedIn = false
    }

    // Apple Guideline 5.1.1(v): apps that support account creation must offer
    // an in-app way to delete the account, not just "contact support". The
    // server side (`DELETE /api/account` in research-os) already existed and
    // already guards against active subscriptions / requires explicit
    // confirm — this just wires the existing endpoint up to a client.
    func deleteAccount() async throws {
        guard let token = Self.readToken() else {
            throw AuthError.failed("未登录")
        }
        var request = URLRequest(url: Self.apiBaseURL.appendingPathComponent("api/account"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["confirm": true])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            struct ErrorBody: Decodable { let error: String?; let message: String? }
            let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
            if body?.error == "active_subscription_exists" {
                throw AuthError.failed("请先在 Research OS 网页端取消订阅，再删除账号")
            }
            throw AuthError.failed(body?.message ?? "删除账号失败，请稍后重试")
        }
        await MainActor.run { self.logout() }
    }

    enum AuthError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            switch self { case .failed(let message): return message }
        }
    }

    // ── Keychain ──────────────────────────────────────────────────
    // A few lines of Security.framework for one string beats pulling in
    // a whole dependency just to store a JWT.

    private static func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeToken(_ token: String) {
        deleteToken()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: token.data(using: .utf8)!,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
