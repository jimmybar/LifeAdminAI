import Foundation
import SwiftData
import SwiftUI

enum DocumentCategory: String, CaseIterable, Identifiable, Codable {
    case personal = "Personal"
    case home = "Home"
    case vehicle = "Vehicle"
    case financial = "Financial"
    case family = "Family"
    case warranty = "Warranty"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .personal: "person.text.rectangle"
        case .home: "house"
        case .vehicle: "car"
        case .financial: "creditcard"
        case .family: "person.2"
        case .warranty: "checkmark.shield"
        case .other: "doc"
        }
    }

    var color: Color {
        switch self {
        case .personal: .blue
        case .home: .mint
        case .vehicle: .indigo
        case .financial: .purple
        case .family: .orange
        case .warranty: .teal
        case .other: .gray
        }
    }

    var localizedName: String {
        switch self {
        case .personal: LanguageManager.tr("cat.personal")
        case .home: LanguageManager.tr("cat.home")
        case .vehicle: LanguageManager.tr("cat.vehicle")
        case .financial: LanguageManager.tr("cat.financial")
        case .family: LanguageManager.tr("cat.family")
        case .warranty: LanguageManager.tr("cat.warranty")
        case .other: LanguageManager.tr("cat.other")
        }
    }
}

enum ProtectionStatus: String, CaseIterable, Codable {
    case protected = "Protegido en iCloud"
    case syncPending = "Sincronizando..."
    case localOnly = "Almacenado en iPhone"
    case syncError = "Error de sincronización"

    var icon: String {
        switch self {
        case .protected: "checkmark.icloud.fill"
        case .syncPending: "arrow.trianglehead.2.clockwise.rotate.90.icloud"
        case .localOnly: "iphone"
        case .syncError: "exclamationmark.icloud.fill"
        }
    }

    var color: Color {
        switch self {
        case .protected: .green
        case .syncPending: .orange
        case .localOnly: .orange
        case .syncError: .red
        }
    }

    var localizedName: String {
        switch self {
        case .protected, .syncPending: LanguageManager.tr("prot.protected")
        case .localOnly: LanguageManager.tr("prot.localOnly")
        case .syncError: LanguageManager.tr("prot.syncError")
        }
    }
}

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case never = "Una sola vez"
    case monthly = "Cada mes"
    case quarterly = "Cada 3 meses"
    case yearly = "Cada año"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .never: "calendar"
        case .monthly: "arrow.2.squarepath"
        case .quarterly: "calendar.badge.clock"
        case .yearly: "arrow.triangle.2.circlepath"
        }
    }

    var localizedName: String {
        switch self {
        case .never: LanguageManager.tr("rec.never")
        case .monthly: LanguageManager.tr("rec.monthly")
        case .quarterly: LanguageManager.tr("rec.quarterly")
        case .yearly: LanguageManager.tr("rec.yearly")
        }
    }
}

@Model
final class LifeDocument {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRawValue: String = DocumentCategory.other.rawValue
    var issuer: String = ""
    var ownerName: String = ""
    var identifier: String = ""
    var amount: Double?
    var issueDate: Date?
    var expirationDate: Date?
    var notes: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var protectionRawValue: String = ProtectionStatus.protected.rawValue
    var reminderEnabled: Bool = false
    var recurrenceRawValue: String = RecurrenceFrequency.never.rawValue
    @Attribute(.externalStorage) var imageData: Data?

    init(
        title: String,
        category: DocumentCategory,
        issuer: String = "",
        ownerName: String = "",
        identifier: String = "",
        amount: Double? = nil,
        expirationDate: Date? = nil,
        notes: String = "",
        protectionStatus: ProtectionStatus = .protected,
        reminderEnabled: Bool = false,
        recurrenceFrequency: RecurrenceFrequency = .never,
        imageData: Data? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.categoryRawValue = category.rawValue
        self.issuer = issuer
        self.ownerName = ownerName
        self.identifier = identifier
        self.amount = amount
        self.expirationDate = expirationDate
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
        self.protectionRawValue = protectionStatus.rawValue
        self.reminderEnabled = reminderEnabled
        self.recurrenceRawValue = recurrenceFrequency.rawValue
        self.imageData = imageData
    }

    var category: DocumentCategory {
        get { DocumentCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var protectionStatus: ProtectionStatus {
        get {
            let status = ProtectionStatus(rawValue: protectionRawValue) ?? .protected
            if status == .syncPending {
                return .protected
            }
            return status
        }
        set { protectionRawValue = newValue.rawValue }
    }

    var recurrenceFrequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: recurrenceRawValue) ?? .never }
        set { recurrenceRawValue = newValue.rawValue }
    }

    var formattedAmount: String? {
        guard let amount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: LanguageManager.resolvedLanguageCode())
        return formatter.string(from: NSNumber(value: amount))
    }
}
