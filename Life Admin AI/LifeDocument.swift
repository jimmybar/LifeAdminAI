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
}

enum ProtectionStatus: String, CaseIterable, Codable {
    case protected = "Protected"
    case syncPending = "Sync Pending"
    case localOnly = "Local Only"
    case syncError = "Sync Error"

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
}

@Model
final class LifeDocument {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRawValue: String = DocumentCategory.other.rawValue
    var issuer: String = ""
    var ownerName: String = ""
    var identifier: String = ""
    var issueDate: Date?
    var expirationDate: Date?
    var notes: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var protectionRawValue: String = ProtectionStatus.localOnly.rawValue
    var reminderEnabled: Bool = false

    init(
        title: String,
        category: DocumentCategory,
        issuer: String = "",
        ownerName: String = "",
        identifier: String = "",
        expirationDate: Date? = nil,
        notes: String = "",
        protectionStatus: ProtectionStatus = .localOnly,
        reminderEnabled: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.categoryRawValue = category.rawValue
        self.issuer = issuer
        self.ownerName = ownerName
        self.identifier = identifier
        self.expirationDate = expirationDate
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
        self.protectionRawValue = protectionStatus.rawValue
        self.reminderEnabled = reminderEnabled
    }

    var category: DocumentCategory {
        get { DocumentCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var protectionStatus: ProtectionStatus {
        get { ProtectionStatus(rawValue: protectionRawValue) ?? .localOnly }
        set { protectionRawValue = newValue.rawValue }
    }
}
