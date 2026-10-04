import AuthenticationServices
import SwiftUI

struct AuthenticationGate: View {
    @Environment(AccountServices.self) private var accountServices

    var body: some View {
        switch accountServices.appleSignInStatus {
        case .checking:
            ProgressView("Verificando tu cuenta…")
                .task {
                    await accountServices.refresh()
                }

        case .signedIn:
            ContentView()

        case .signedOut:
            AppleLoginView()

        case .error(let message):
            AppleLoginView(errorMessage: message)
        }
    }
}

private struct AppleLoginView: View {
    @Environment(AccountServices.self) private var accountServices
    var errorMessage: String?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
                .frame(width: 128, height: 128)
                .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 32))

            VStack(spacing: 10) {
                Text("Life Admin AI")
                    .font(.largeTitle.bold())

                Text("Organiza y protege tus documentos importantes.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                accountServices.handleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .accessibilityLabel("Iniciar sesión con Apple")

            Text("Tu identificador de sesión se guarda de forma segura en el Keychain. La sincronización usa por separado la cuenta de iCloud del dispositivo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AuthenticationGate()
        .environment(AccountServices())
}
