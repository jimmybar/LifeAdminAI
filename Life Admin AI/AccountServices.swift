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
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.refreshAppleSignIn()
            }
            group.addTask {
                await self.refreshICloud()
            }
        }
    }

    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                appleSignInStatus = .error(LanguageManager.tr("acc.errInvalidCred"))
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
                appleSignInStatus = .signedIn(name: displayName ?? LanguageManager.tr("acc.defaultName"))
            } catch {
                appleSignInStatus = .error(LanguageManager.tr("acc.errKeychain"))
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
        if iCloudStatus == .checking {
            iCloudStatus = .checking
        }

        let result: (CKAccountStatus, Error?)? = await withTimeout(seconds: 3.0) {
            await withCheckedContinuation { continuation in
                CKContainer.default().accountStatus { status, error in
                    continuation.resume(returning: (status, error))
                }
            }
        }

        guard let (status, error) = result else {
            iCloudStatus = .temporarilyUnavailable
            return
        }

        if let error {
            iCloudStatus = .error(error.localizedDescription)
            return
        }

        switch status {
        case .available:
            iCloudStatus = .available
        case .noAccount:
            iCloudStatus = .noAccount
        case .restricted:
            iCloudStatus = .restricted
        case .temporarilyUnavailable:
            iCloudStatus = .temporarilyUnavailable
        case .couldNotDetermine:
            iCloudStatus = .error(LanguageManager.tr("acc.errCloudCheck"))
        @unknown default:
            iCloudStatus = .error(LanguageManager.tr("acc.errCloudUnknown"))
        }
    }

    func refreshAppleSignIn() async {
        guard let userID = KeychainStore.value(for: userIDKey) else {
            appleSignInStatus = .signedOut
            return
        }

        if case .signedIn = appleSignInStatus {
            // Mantener .signedIn mientras se verifica en segundo plano
        } else {
            appleSignInStatus = .checking
        }

        let state: ASAuthorizationAppleIDProvider.CredentialState? = await withTimeout(seconds: 3.0) {
            await withCheckedContinuation { continuation in
                ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                    continuation.resume(returning: state)
                }
            }
        }

        guard let state else {
            if case .signedIn = appleSignInStatus {
                // Si ya estaba iniciada la sesión y no responde la red, conservar la sesión actual
            } else {
                appleSignInStatus = .signedOut
            }
            return
        }

        switch state {
        case .authorized:
            let displayName = UserDefaults.standard.string(forKey: displayNameKey)
            appleSignInStatus = .signedIn(name: displayName ?? LanguageManager.tr("acc.defaultName"))
        case .revoked, .notFound, .transferred:
            signOut()
        @unknown default:
            if case .signedIn = appleSignInStatus {
                // Mantener estado si no hay revocación confirmada
            } else {
                appleSignInStatus = .signedOut
            }
        }
    }
}

private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async -> T) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            await operation()
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let firstResult = await group.next()
        group.cancelAll()
        return firstResult ?? nil
    }
}

private enum KeychainStore {
    static func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }

    static func value(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error {
        case unhandledError(status: OSStatus)
    }
}
