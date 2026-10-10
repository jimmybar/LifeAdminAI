import LocalAuthentication
import SwiftUI

struct AppLockGate<Content: View>: View {
    @AppStorage("appLockEnabled") private var appLockEnabled: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked: Bool = false
    @State private var isAuthenticating: Bool = false
    @State private var authError: String? = nil
    @State private var languageManager = LanguageManager.shared

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content

            if appLockEnabled && !isUnlocked {
                lockOverlay
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onAppear {
            if appLockEnabled && !isUnlocked {
                authenticate()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && appLockEnabled {
                isUnlocked = false
            } else if newPhase == .active && appLockEnabled && !isUnlocked {
                authenticate()
            }
        }
    }

    private var lockOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.indigo)
                .padding(24)
                .background(.indigo.opacity(0.1), in: Circle())

            VStack(spacing: 8) {
                Text("Life Admin AI")
                    .font(.largeTitle.bold())

                Text(languageManager.tr("lock.subtitle"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let authError {
                Text(authError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                authenticate()
            } label: {
                Label(languageManager.tr("lock.unlockBtn"), systemImage: "faceid")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .disabled(isAuthenticating)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil

        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = languageManager.tr("lock.reason")
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evaluateError in
                DispatchQueue.main.async {
                    isAuthenticating = false
                    if success {
                        withAnimation {
                            isUnlocked = true
                        }
                    } else {
                        if let evaluateError {
                            authError = evaluateError.localizedDescription
                        }
                    }
                }
            }
        } else {
            isAuthenticating = false
            if let error {
                authError = error.localizedDescription
            } else {
                authError = languageManager.tr("lock.noBiometrics")
            }
        }
    }
}

enum BiometricHelper {
    static func verifyBiometrics(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }
}
