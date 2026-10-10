import CloudKit
import SwiftUI
import UIKit

@MainActor
final class FamilySharingService {
    static let shared = FamilySharingService()

    private init() {}

    /// Prepara y devuelve un controlador de compartición CloudKit (CKShare) para un documento específico.
    /// Al compartir el registro en CloudKit, tanto los metadatos como los archivos de imagen adjuntos
    /// (almacenados como CKAsset en .externalStorage) se comparten automáticamente con los miembros invitados.
    func makeShareController(
        for document: LifeDocument,
        completion: @escaping (Result<UICloudSharingController, Error>) -> Void
    ) {
        let container = CKContainer.default()
        let recordZone = CKRecordZone(zoneName: "LifeAdminFamilyZone")

        // Creación/recuperación del CKShare para la zona o documento
        let share = CKShare(recordZoneID: recordZone.zoneID)
        share[CKShare.SystemFieldKey.title] = "Documento: \(document.title)" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "com.lifeadminai.familydocument" as CKRecordValue

        let controller = UICloudSharingController(share: share, container: container)
        completion(.success(controller))
    }
}

/// Representable para mostrar el modal nativo de iOS para invitar y gestionar miembros de la familia en CloudKit.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Error al guardar la compartición de CloudKit: \(error.localizedDescription)")
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            return "Documentos de Familia Life Admin"
        }
    }
}
