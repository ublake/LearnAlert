import AuthenticationServices
import Foundation
import Observation
import Security

struct LearnAlertAccount: Codable, Equatable, Sendable {
    let appleUserIdentifier: String
    let displayName: String?
    let emailAddress: String?
}

@MainActor
@Observable
final class AccountManager {
    static let shared = AccountManager()

    private(set) var account: LearnAlertAccount?
    private(set) var credentialNeedsAttention = false

    var isSignedIn: Bool { account != nil && !credentialNeedsAttention }

    var displayName: String {
        guard let account else { return "Not signed in" }
        return account.displayName ?? account.emailAddress ?? "Apple account"
    }

    private let keychain = AccountKeychain()

    private init() {
        account = try? keychain.load()
    }

    func completeSignIn(with authorization: ASAuthorization) throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AccountError.invalidCredential
        }

        let existingAccount = account
        let formattedName = PersonNameComponentsFormatter().string(from: credential.fullName ?? .init())
        let newAccount = LearnAlertAccount(
            appleUserIdentifier: credential.user,
            displayName: formattedName.isEmpty ? existingAccount?.displayName : formattedName,
            emailAddress: credential.email ?? existingAccount?.emailAddress
        )

        try keychain.save(newAccount)
        account = newAccount
        credentialNeedsAttention = false
    }

    func validateCredentialState() async {
        guard let account else { return }

        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(
                forUserID: account.appleUserIdentifier
            )
            switch state {
            case .authorized:
                credentialNeedsAttention = false
            case .revoked, .notFound, .transferred:
                credentialNeedsAttention = true
            @unknown default:
                credentialNeedsAttention = true
            }
        } catch {
            // An offline validation failure should not erase a valid local account.
        }
    }

    func signOut() {
        try? keychain.delete()
        account = nil
        credentialNeedsAttention = false
    }
}

private enum AccountError: LocalizedError {
    case invalidCredential
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Apple did not return a usable account credential."
        case .keychain:
            return "LearnAlert could not securely save the account on this device."
        }
    }
}

private struct AccountKeychain {
    private let service = "com.learnalert.account"
    private let accountKey = "apple-account"

    func load() throws -> LearnAlertAccount? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AccountError.keychain(status)
        }
        return try JSONDecoder().decode(LearnAlertAccount.self, from: data)
    }

    func save(_ account: LearnAlertAccount) throws {
        let data = try JSONEncoder().encode(account)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AccountError.keychain(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw AccountError.keychain(updateStatus)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AccountError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
    }
}
