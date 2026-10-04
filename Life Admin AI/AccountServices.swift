import AuthenticationServices
import CloudKit
import Foundation
import Observation
import Security

@MainActor
@Observable
final class AccountServices {
    enum AppleSignInStatus: Equatable {
        case signedOut
        case checking
        case signedIn(name: String)
        case error(String)
    }

    enum ICloudStatus: Equatable {
        case checking
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case error(String)
    }

    private(set) var appleSignInStatus: AppleSignInStatus = .checking
    private(set) var iCloudStatus: ICloudStatus = .checking

    private let userIDKey = "appleUserIdentifier"
    private let displayNameKey = "appleDisplayName"

    func refresh() async {
        await refreshAppleSignIn()
        await refreshICloud()
    }

    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                appleSignInStatus = .error("Apple no devolvió una credencial válida.")
                return
            }

            do {
                try KeychainStore.save(credential.user, for: userIDKey)
                let providedName = credential.fullName.map {
                    PersonNameComponentsFormatter().string(from: $0)
                }?.trimmingCharacters(in: .whitespacesAndNewlines)

                if let providedName, !providedName.isEmpty {
                    UserDefaults.standard.set(providedName, forKey: displayNameKey)
                }

                let displayName = UserDefaults.standard.string(forKey: displayNameKey)
                appleSignInStatus = .signedIn(name: displayName ?? "Cuenta de Apple")
            } catch {
                appleSignInStatus = .error("No se pudo guardar la sesión de forma segura.")
            }

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                appleSignInStatus = .signedOut
            } else {
                appleSignInStatus = .error(error.localizedDescription)
            }
        }
    }

    func signOut() {
        KeychainStore.delete(userIDKey)
        UserDefaults.standard.removeObject(forKey: displayNameKey)
        appleSignInStatus = .signedOut
    }

    func refreshICloud() async {
        iCloudStatus = .checking

        let result: (CKAccountStatus, Error?) = await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                continuation.resume(returning: (status, error))
            }
        }

        if let error = result.1 {
            iCloudStatus = .error(error.localizedDescription)
            return
        }

        switch result.0 {
        case .available:
            iCloudStatus = .available
        case .noAccount:
            iCloudStatus = .noAccount
        case .restricted:
            iCloudStatus = .restricted
        case .temporarilyUnavailable:
            iCloudStatus = .temporarilyUnavailable
        case .couldNotDetermine:
            iCloudStatus = .error("No se pudo verificar la cuenta de iCloud.")
        @unknown default:
            iCloudStatus = .error("Estado de iCloud desconocido.")
        }
    }

    private func refreshAppleSignIn() async {
        guard let userID = KeychainStore.value(for: userIDKey) else {
            appleSignInStatus = .signedOut
            return
        }

        appleSignInStatus = .checking
        let state = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }

        switch state {
        case .authorized:
            let displayName = UserDefaults.standard.string(forKey: displayNameKey)
            appleSignInStatus = .signedIn(name: displayName ?? "Cuenta de Apple")
        case .revoked, .notFound, .transferred:
            signOut()
        @unknown default:
            appleSignInStatus = .signedOut
        }
    }
}

private enum KeychainStore {
    static func save(_ value: String, for key: String) throws {
        delete(key)

        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "LifeAdminAI",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func value(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "LifeAdminAI",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "LifeAdminAI"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
