import SwiftData
import SwiftUI

@main
struct LifeAdminAIApp: App {
    @State private var accountServices = AccountServices()
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([LifeDocument.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("No se pudo crear el almacén de documentos: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationGate()
                .environment(accountServices)
        }
        .modelContainer(modelContainer)
    }
}
