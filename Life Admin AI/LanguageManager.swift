import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case spanish = "es"
    case english = "en"

    var id: String { rawValue }

    func displayName(in currentLang: AppLanguage) -> String {
        switch self {
        case .system:
            return currentLang == .english ? "System Default" : "Predeterminado del sistema"
        case .spanish:
            return "Español"
        case .english:
            return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            return Locale.autoupdatingCurrent
        case .spanish:
            return Locale(identifier: "es")
        case .english:
            return Locale(identifier: "en")
        }
    }
}

@MainActor
@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "appLanguagePreference")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguagePreference") ?? AppLanguage.system.rawValue
        self.selectedLanguage = AppLanguage(rawValue: saved) ?? .system
    }

    var locale: Locale {
        selectedLanguage.locale
    }

    var currentLanguageCode: String {
        switch selectedLanguage {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? Locale.current.language.languageCode?.identifier ?? "en"
            return preferred.hasPrefix("es") ? "es" : "en"
        case .spanish:
            return "es"
        case .english:
            return "en"
        }
    }

    func tr(_ key: String, _ args: CVarArg...) -> String {
        let code = currentLanguageCode
        let raw = Localization.string(for: key, language: code)
        if args.isEmpty {
            return raw
        }
        return String(format: raw, arguments: args)
    }

    func tr(_ key: String) -> String {
        let code = currentLanguageCode
        return Localization.string(for: key, language: code)
    }

    nonisolated static func resolvedLanguageCode() -> String {
        let saved = UserDefaults.standard.string(forKey: "appLanguagePreference") ?? AppLanguage.system.rawValue
        let lang = AppLanguage(rawValue: saved) ?? .system
        switch lang {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? Locale.current.language.languageCode?.identifier ?? "en"
            return preferred.hasPrefix("es") ? "es" : "en"
        case .spanish:
            return "es"
        case .english:
            return "en"
        }
    }

    nonisolated static func tr(_ key: String, _ args: [CVarArg]) -> String {
        let code = resolvedLanguageCode()
        let raw = Localization.string(for: key, language: code)
        if args.isEmpty {
            return raw
        }
        return String(format: raw, arguments: args)
    }

    nonisolated static func tr(_ key: String) -> String {
        let code = resolvedLanguageCode()
        return Localization.string(for: key, language: code)
    }
}

enum Localization {
    private static let spanishStrings: [String: String] = [
        // Categories
        "cat.personal": "Personal",
        "cat.home": "Hogar",
        "cat.vehicle": "Vehículo",
        "cat.financial": "Financiero",
        "cat.family": "Familia",
        "cat.warranty": "Garantía",
        "cat.other": "Otro",

        // Protection
        "prot.protected": "Protegido en iCloud",
        "prot.syncPending": "Sincronizando...",
        "prot.localOnly": "Almacenado en iPhone",
        "prot.syncError": "Error de sincronización",

        // Recurrence
        "rec.never": "Una sola vez",
        "rec.monthly": "Cada mes",
        "rec.quarterly": "Cada 3 meses",
        "rec.yearly": "Cada año",

        // Tabs
        "tab.home": "Inicio",
        "tab.documents": "Documentos",
        "tab.upcoming": "Próximos",
        "tab.settings": "Ajustes",

        // Home
        "home.welcome": "Bienvenido",
        "home.subtitle": "Mantén el control de tus documentos y facturas.",
        "home.plan.free": "Life Admin Base",
        "home.plan.pro": "Life Admin Pro",
        "home.plan.freeDesc": "%d/10 documentos usados (iCloud Sync)",
        "home.plan.proDesc": "Documentos Ilimitados • AI • Recordatorios Recurrentes",
        "home.plan.getPro": "Obtener Pro",
        "home.prot.descProtected": "Tus documentos se guardan localmente y se respaldan en tu iCloud privado.",
        "home.prot.descLocal": "Los documentos se guardan localmente hasta que iCloud esté disponible.",
        "home.prot.freeIncluded": "• Incluido",
        "home.quickAdd.title": "Agregar documento o factura",
        "home.quickAdd.desc": "Escanea o sube fotos/PDF. Configura recordatorios únicos o recurrentes.",
        "home.empty.title": "Tus documentos aparecerán aquí",
        "home.empty.desc": "Agrega tu primer documento o factura para realizar seguimiento de fechas, montos y recordatorios.",
        "home.empty.button": "Crear documento",
        "home.sec.upcoming": "Próximos a vencer",
        "home.sec.recent": "Agregados recientemente",
        "home.sec.viewAll": "Ver todos",
        "home.sec.viewLib": "Ver biblioteca",

        // Documents Library
        "doc.title": "Documentos",
        "doc.searchPrompt": "Buscar título, emisor, identificador o monto...",
        "doc.filterAll": "Todos",
        "doc.resultsCount": "%d resultados encontrados",
        "doc.emptyTitle": "Sin documentos",
        "doc.emptyNoResults": "No se encontraron resultados",
        "doc.emptyDesc": "Crea o escanea un documento para comenzar.",
        "doc.emptyResultsDesc": "Intenta buscar con otros términos o cambia la categoría.",
        "doc.addBtn": "Agregar documento",

        // Upcoming
        "up.title": "Próximos",
        "up.h30": "30 días",
        "up.h90": "90 días",
        "up.h6m": "6 meses",
        "up.h1y": "1 año",
        "up.hAll": "Todos",
        "up.secExpired": "Vencidos",
        "up.secUpcoming": "Próximos (%d)",
        "up.emptyTitle": "Sin vencimientos próximos",
        "up.emptyDesc": "Los documentos con fechas en los próximos días o meses aparecerán aquí.",

        // Add Document
        "add.navTitle": "Nuevo documento",
        "add.headerCapture": "Captura de factura o documento (Foto o PDF)",
        "add.footerCapture": "Puedes tomar una foto, subir una imagen del carrete o seleccionar un archivo PDF de tu factura. Apple Intelligence extraerá el monto y datos automáticamente.",
        "add.btnCamera": "Cámara",
        "add.btnPhoto": "Subir foto",
        "add.btnPDF": "Subir PDF",
        "add.attachedHeader": "Archivo/Imagen adjunta",
        "add.attachedSub": "Se guardará junto con la factura o documento.",
        "add.analyzing": "Leyendo y analizando con Apple Intelligence…",
        "add.secDetails": "Datos del documento",
        "add.fTitle": "Título / Concepto (ej. Factura Luz)",
        "add.fCategory": "Categoría",
        "add.fIssuer": "Emisor (ej. CFE / Empresa)",
        "add.fOwner": "Titular o nombre",
        "add.fIdentifier": "Número o identificador de factura",
        "add.fAmount": "Monto total ($)",
        "add.secDateHeader": "Fecha y Recordatorio Recurrente",
        "add.secDateFooter": "Configura alertas únicas en el plan Base o recurrentes (mensual, trimestral o anual) en Pro.",
        "add.toggleHasExp": "Tiene fecha de vencimiento o pago",
        "add.dateExp": "Fecha de vencimiento",
        "add.toggleReminder": "Programar recordatorio en iPhone",
        "add.pickerFreq": "Frecuencia de recordatorio",
        "add.secNotes": "Notas adicionales",
        "add.fNotesPlaceholder": "Notas u observaciones...",
        "add.stCloud": "Guardado y respaldado en tu iCloud privado",
        "add.stLocal": "Guardado localmente en este iPhone",
        "add.btnCancel": "Cancelar",
        "add.btnSave": "Guardar",
        "add.errTitle": "No se pudo analizar la imagen o PDF",
        "add.btnSettings": "Abrir Configuración",
        "add.btnOK": "Aceptar",

        // Document Detail
        "det.navTitle": "Documento",
        "det.secAttached": "Factura / Imagen / PDF adjunto",
        "det.secProt": "Estado de Protección",
        "det.protLocalDesc": "Este documento permanece en el dispositivo hasta que iCloud esté disponible.",
        "det.protCloudDesc": "Este documento está protegido y respaldado en tu iCloud privado.",
        "det.secDetails": "Detalles",
        "det.lblIssuer": "Emisor",
        "det.lblOwner": "Titular",
        "det.lblID": "Identificador / Factura #",
        "det.lblAmount": "Monto total pagado / por pagar",
        "det.lblExpDate": "Fecha de vencimiento",
        "det.lblReminder": "Recordatorio programado",
        "det.lblFreq": "Frecuencia del recordatorio",
        "det.lblNotes": "Notas",
        "det.btnDelete": "Eliminar documento por completo",
        "det.dialogTitle": "¿Eliminar este documento por completo?",
        "det.dialogMsg": "Esto eliminará la información, la imagen/PDF adjunto y cancelará todas las notificaciones de forma permanente.",
        "det.btnDeleteConfirm": "Eliminar permanentemente",
        "det.previewTitle": "Vista previa del archivo",
        "det.btnClose": "Cerrar",
        "det.btnExport": "Exportar / Compartir",
        "det.exportTitle": "Resumen del documento",

        // Settings
        "set.title": "Configuración",
        "set.secPlan": "Plan actual",
        "set.planFreeDesc": "10 documentos incluidos. iCloud Sync y Face ID.",
        "set.planProDesc": "Documentos Ilimitados + Categorías Avanzadas",
        "set.btnManage": "Gestionar",
        "set.btnGetPro": "Obtener Pro ($3.99/mo)",
        "set.toggleTesting": "Modo Pruebas Pro (Testing)",
        "set.secAccount": "Cuenta de la app",
        "set.accChecking": "Verificando cuenta…",
        "set.accSignedAs": "Conectado como %@",
        "set.accSignOut": "Cerrar sesión",
        "set.accSignInApple": "Iniciar sesión con Apple",
        "set.accFooter": "Iniciar sesión con Apple identifica tu cuenta en la app. Apple solo comparte el nombre y correo la primera vez que autorizas.",
        "set.secICloud": "Sincronización con iCloud",
        "set.cloudChecking": "Verificando iCloud…",
        "set.cloudAvailable": "Sincronización disponible",
        "set.cloudAvailDesc": "Los documentos se sincronizan con tu base privada de iCloud.",
        "set.cloudNoAccount": "No hay una cuenta de iCloud",
        "set.cloudNoAccDesc": "Inicia sesión en iCloud desde Configuración del iPhone y activa iCloud Drive.",
        "set.cloudRestricted": "iCloud está restringido",
        "set.cloudTempUnavail": "iCloud no está disponible temporalmente",
        "set.btnRefresh": "Actualizar estado",
        "set.secPrivacy": "Privacidad y seguridad",
        "set.toggleLock": "Bloqueo de la app (Face ID / Touch ID)",
        "set.secLanguage": "Idioma de la aplicación",
        "set.pickerLanguage": "Idioma",
        "set.secAbout": "Acerca de",
        "set.btnIntro": "Ver introducción",
        "set.lblVersion": "Versión",
        "set.linkPrivacy": "Política de privacidad de Apple",
        "set.footerDesc": "El escaneo, OCR y análisis con Apple Intelligence se realizan en el dispositivo. Los documentos e imágenes se respaldan en tu cuenta privada de iCloud.",
        "set.btnRetry": "Reintentar",

        // App Lock
        "lock.subtitle": "App bloqueada por seguridad",
        "lock.unlockBtn": "Desbloquear con Face ID / Touch ID",
        "lock.reason": "Desbloquea Life Admin AI para acceder a tus documentos",
        "lock.noBiometrics": "Biometría o código de acceso no disponible",

        // Paywall
        "pay.title": "Life Admin Pro",
        "pay.price": "$3.99 / mes",
        "pay.sub": "Desbloquea el potencial ilimitado para organizar toda tu vida y documentos importantes.",
        "pay.planFreeTitle": "Life Admin Base",
        "pay.planFreePrice": "Gratis",
        "pay.planFreeBadge": "Plan Actual Base",
        "pay.planFreeDesc": "10 documentos + iCloud + Face ID",
        "pay.planProTitle": "Life Admin Pro",
        "pay.planProPrice": "$3.99 / mes",
        "pay.planProBadge": "Recomendado",
        "pay.planProDesc": "Documentos Ilimitados • AI • Recordatorios Recurrentes",
        "pay.compareHeader": "Comparativa entre Planes",
        "pay.compLimit": "Límite de documentos",
        "pay.compLimitFree": "10 documentos",
        "pay.compLimitPro": "Ilimitados",
        "pay.compAI": "Apple Intelligence AI",
        "pay.compAIRec": "Básica (10 docs)",
        "pay.compAIRecPro": "Ilimitada",
        "pay.compReminders": "Recordatorios Recurrentes",
        "pay.compRemindersFree": "Una sola vez",
        "pay.compRemindersPro": "Mensual / Trimestral / Anual",
        "pay.compICloud": "Sincronización iCloud",
        "pay.compFaceID": "Bloqueo Face ID / Touch ID",
        "pay.allInPro": "Todo en Pro:",
        "pay.feat1Title": "Documentos Ilimitados",
        "pay.feat1Sub": "Sin límite de 10 documentos.",
        "pay.feat2Title": "AI Ilimitada / Fair-Use",
        "pay.feat2Sub": "Procesa y analiza todas tus facturas sin restricciones.",
        "pay.feat3Title": "Categorías Avanzadas",
        "pay.feat3Sub": "Pasaportes, seguros, garantías, contratos, vehículos, hogar, etc.",
        "pay.feat4Title": "Búsqueda Inteligente & Smart Reminders",
        "pay.feat4Sub": "Localiza cualquier dato en segundos y recibe alertas avanzadas.",
        "pay.feat5Title": "Exportación & Backup Cifrado",
        "pay.feat5Sub": "Exporta tus archivos e imágenes para compartirlos fácilmente.",
        "pay.feat6Title": "Sincronización iCloud & Notificaciones",
        "pay.feat6Sub": "Respaldo automático en tu iCloud privado y notificaciones locales seguras.",
        "pay.secHeader": "Tu seguridad es nuestra prioridad base",
        "pay.secSub": "iCloud Sync y la protección con Face ID están incluidos en la versión base de Life Admin.",
        "pay.btnSubscribe": "Suscribirme a Pro — $3.99/mes",
        "pay.btnProActive": "Suscripción Pro Activa",
        "pay.btnRestore": "Restaurar compras",
        "pay.toggleTest": "Modo de Pruebas / Testing Pro",
        "pay.disclaimer": "La suscripción se renueva automáticamente cada mes a $3.99/mes a menos que se cancele 24 horas antes del final del periodo actual.",
        "pay.eula": "Términos de uso (EULA)",
        "pay.privacy": "Política de privacidad",
        "pay.prodMonthly": "Life Admin Pro Mensual",
        "pay.limitReachedTitle": "Límite de 10 documentos alcanzado",
        "pay.limitReachedMsg": "El plan Life Admin Base incluye hasta 10 documentos. Suscríbete a Pro para agregar documentos ilimitados.",
        "pay.recOnlyPro": "Los recordatorios recurrentes (mensuales, trimestrales, anuales) requieren Life Admin Pro.",
        "pay.catOnlyPro": "Las categorías avanzadas requieren Life Admin Pro.",

        // Onboarding
        "onb.p1Title": "Documentos y facturas organizados",
        "onb.p1Msg": "Guarda facturas en fotos o archivos PDF en un solo lugar y encuéntralos rápidamente.",
        "onb.p2Title": "Fechas y recordatorios recurrentes",
        "onb.p2Msg": "Recibe notificaciones automáticas únicas o recurrentes (mensuales, trimestrales o anuales).",
        "onb.p3Title": "Protección privada",
        "onb.p3Msg": "Tus imágenes y datos se analizan en el dispositivo y se respaldan en tu iCloud privado.",
        "onb.btnSkip": "Omitir",
        "onb.btnContinue": "Continuar",
        "onb.btnStart": "Comenzar",

        // Notifications
        "notif.dueTitle": "Vencimiento de pago: %@ (%@)",
        "notif.dueBody": "La factura '%@' por %@ vence hoy. Recurrencia: %@.",
        "notif.dueNoAmtTitle": "Vencimiento de documento: %@",
        "notif.dueNoAmtBody": "El documento '%@' vence o requiere acción hoy. Recurrencia: %@.",
        "notif.prevTitle": "Recordatorio: %@",
        "notif.prevBody": "El documento '%@' vencerá en 7 días.",

        // Authentication Gate & Account
        "gate.checking": "Verificando tu cuenta…",
        "gate.sub": "Organiza y protege tus documentos importantes.",
        "gate.appleBtnLabel": "Iniciar sesión con Apple",
        "gate.footer": "Tu identificador de sesión se guarda de forma segura en el Keychain. La sincronización usa por separado la cuenta de iCloud del dispositivo.",
        "acc.defaultName": "Cuenta de Apple",
        "acc.errInvalidCred": "Apple no devolvió una credencial válida.",
        "acc.errKeychain": "No se pudo guardar la sesión de forma segura.",
        "acc.errCloudCheck": "No se pudo verificar la cuenta de iCloud.",
        "acc.errCloudUnknown": "Estado de iCloud desconocido.",

        // Errors & Subscription
        "err.noText": "No se pudo reconocer texto en el documento.",
        "err.invalidImage": "No se pudo procesar una de las páginas capturadas.",
        "sub.errFetch": "No se pudieron cargar los planes de suscripción desde App Store Connect.",
        "sub.errRestore": "No se pudieron restaurar las compras."
    ]

    private static let englishStrings: [String: String] = [
        // Categories
        "cat.personal": "Personal",
        "cat.home": "Home",
        "cat.vehicle": "Vehicle",
        "cat.financial": "Financial",
        "cat.family": "Family",
        "cat.warranty": "Warranty",
        "cat.other": "Other",

        // Protection
        "prot.protected": "Protected in iCloud",
        "prot.syncPending": "Syncing...",
        "prot.localOnly": "Stored on iPhone",
        "prot.syncError": "Sync Error",

        // Recurrence
        "rec.never": "One-time",
        "rec.monthly": "Monthly",
        "rec.quarterly": "Every 3 months",
        "rec.yearly": "Yearly",

        // Tabs
        "tab.home": "Home",
        "tab.documents": "Documents",
        "tab.upcoming": "Upcoming",
        "tab.settings": "Settings",

        // Home
        "home.welcome": "Welcome",
        "home.subtitle": "Keep control of your important documents and bills.",
        "home.plan.free": "Life Admin Base",
        "home.plan.pro": "Life Admin Pro",
        "home.plan.freeDesc": "%d/10 documents used (iCloud Sync)",
        "home.plan.proDesc": "Unlimited Documents • AI • Recurring Reminders",
        "home.plan.getPro": "Get Pro",
        "home.prot.descProtected": "Your documents are stored locally and backed up in your private iCloud.",
        "home.prot.descLocal": "Documents are saved locally until iCloud becomes available.",
        "home.prot.freeIncluded": "• Included",
        "home.quickAdd.title": "Add document or bill",
        "home.quickAdd.desc": "Scan or upload photos/PDFs. Set one-time or recurring reminders.",
        "home.empty.title": "Your documents will appear here",
        "home.empty.desc": "Add your first document or bill to track dates, amounts, and reminders.",
        "home.empty.button": "Create document",
        "home.sec.upcoming": "Expiring soon",
        "home.sec.recent": "Recently added",
        "home.sec.viewAll": "View all",
        "home.sec.viewLib": "View library",

        // Documents Library
        "doc.title": "Documents",
        "doc.searchPrompt": "Search title, issuer, ID or amount...",
        "doc.filterAll": "All",
        "doc.resultsCount": "%d results found",
        "doc.emptyTitle": "No documents",
        "doc.emptyNoResults": "No results found",
        "doc.emptyDesc": "Create or scan a document to get started.",
        "doc.emptyResultsDesc": "Try searching with different terms or change the category.",
        "doc.addBtn": "Add document",

        // Upcoming
        "up.title": "Upcoming",
        "up.h30": "30 days",
        "up.h90": "90 days",
        "up.h6m": "6 months",
        "up.h1y": "1 year",
        "up.hAll": "All",
        "up.secExpired": "Expired",
        "up.secUpcoming": "Upcoming (%d)",
        "up.emptyTitle": "No upcoming expirations",
        "up.emptyDesc": "Documents with dates in the coming days or months will appear here.",

        // Add Document
        "add.navTitle": "New document",
        "add.headerCapture": "Capture document or bill (Photo or PDF)",
        "add.footerCapture": "You can take a photo, upload an image from your camera roll, or select a PDF file of your bill. Apple Intelligence will extract the amount and details automatically.",
        "add.btnCamera": "Camera",
        "add.btnPhoto": "Upload photo",
        "add.btnPDF": "Upload PDF",
        "add.attachedHeader": "Attached File/Image",
        "add.attachedSub": "Will be saved alongside the bill or document.",
        "add.analyzing": "Reading and analyzing with Apple Intelligence…",
        "add.secDetails": "Document Details",
        "add.fTitle": "Title / Concept (e.g. Electricity Bill)",
        "add.fCategory": "Category",
        "add.fIssuer": "Issuer (e.g. Company name)",
        "add.fOwner": "Owner name",
        "add.fIdentifier": "Invoice / Document ID #",
        "add.fAmount": "Total Amount ($)",
        "add.secDateHeader": "Date & Recurring Reminder",
        "add.secDateFooter": "Set one-time alerts in Base plan or recurring alerts (monthly, quarterly, yearly) in Pro.",
        "add.toggleHasExp": "Has expiration or payment date",
        "add.dateExp": "Expiration date",
        "add.toggleReminder": "Schedule reminder on iPhone",
        "add.pickerFreq": "Reminder frequency",
        "add.secNotes": "Additional Notes",
        "add.fNotesPlaceholder": "Notes or remarks...",
        "add.stCloud": "Saved and backed up in your private iCloud",
        "add.stLocal": "Saved locally on this iPhone",
        "add.btnCancel": "Cancel",
        "add.btnSave": "Save",
        "add.errTitle": "Could not analyze image or PDF",
        "add.btnSettings": "Open Settings",
        "add.btnOK": "OK",

        // Document Detail
        "det.navTitle": "Document",
        "det.secAttached": "Bill / Image / PDF Attached",
        "det.secProt": "Protection Status",
        "det.protLocalDesc": "This document remains on the device until iCloud is available.",
        "det.protCloudDesc": "This document is protected and backed up in your private iCloud.",
        "det.secDetails": "Details",
        "det.lblIssuer": "Issuer",
        "det.lblOwner": "Owner",
        "det.lblID": "Invoice / Document ID #",
        "det.lblAmount": "Total amount paid / due",
        "det.lblExpDate": "Expiration date",
        "det.lblReminder": "Scheduled reminder",
        "det.lblFreq": "Reminder frequency",
        "det.lblNotes": "Notes",
        "det.btnDelete": "Delete document completely",
        "det.dialogTitle": "Delete this document completely?",
        "det.dialogMsg": "This will permanently delete the information, attached image/PDF, and cancel all notifications.",
        "det.btnDeleteConfirm": "Delete permanently",
        "det.previewTitle": "File Preview",
        "det.btnClose": "Close",
        "det.btnExport": "Export / Share",
        "det.exportTitle": "Document Summary",

        // Settings
        "set.title": "Settings",
        "set.secPlan": "Current Plan",
        "set.planFreeDesc": "10 documents included. iCloud Sync and Face ID.",
        "set.planProDesc": "Unlimited Documents + Advanced Categories",
        "set.btnManage": "Manage",
        "set.btnGetPro": "Get Pro ($3.99/mo)",
        "set.toggleTesting": "Pro Testing Mode",
        "set.secAccount": "App Account",
        "set.accChecking": "Checking account…",
        "set.accSignedAs": "Signed in as %@",
        "set.accSignOut": "Sign out",
        "set.accSignInApple": "Sign in with Apple",
        "set.accFooter": "Sign in with Apple identifies your app account. Apple only shares your name and email the first time you authorize.",
        "set.secICloud": "iCloud Sync",
        "set.cloudChecking": "Checking iCloud…",
        "set.cloudAvailable": "Sync Available",
        "set.cloudAvailDesc": "Documents sync with your private iCloud database.",
        "set.cloudNoAccount": "No iCloud Account",
        "set.cloudNoAccDesc": "Sign in to iCloud in iPhone Settings and enable iCloud Drive.",
        "set.cloudRestricted": "iCloud is Restricted",
        "set.cloudTempUnavail": "iCloud is Temporarily Unavailable",
        "set.btnRefresh": "Refresh Status",
        "set.secPrivacy": "Privacy & Security",
        "set.toggleLock": "App Lock (Face ID / Touch ID)",
        "set.secLanguage": "App Language",
        "set.pickerLanguage": "Language",
        "set.secAbout": "About",
        "set.btnIntro": "View Intro",
        "set.lblVersion": "Version",
        "set.linkPrivacy": "Apple Privacy Policy",
        "set.footerDesc": "Scanning, OCR, and Apple Intelligence analysis are performed on-device. Documents and images are backed up in your private iCloud account.",
        "set.btnRetry": "Retry",

        // App Lock
        "lock.subtitle": "App locked for security",
        "lock.unlockBtn": "Unlock with Face ID / Touch ID",
        "lock.reason": "Unlock Life Admin AI to access your documents",
        "lock.noBiometrics": "Biometrics or passcode unavailable",

        // Paywall
        "pay.title": "Life Admin Pro",
        "pay.price": "$3.99 / month",
        "pay.sub": "Unlock unlimited potential to organize your entire life and important documents.",
        "pay.planFreeTitle": "Life Admin Base",
        "pay.planFreePrice": "Free",
        "pay.planFreeBadge": "Current Base Plan",
        "pay.planFreeDesc": "10 documents + iCloud + Face ID",
        "pay.planProTitle": "Life Admin Pro",
        "pay.planProPrice": "$3.99 / mo",
        "pay.planProBadge": "Recommended",
        "pay.planProDesc": "Unlimited Documents + AI + Recurring Reminders",
        "pay.compareHeader": "Plan Comparison",
        "pay.compLimit": "Document Limit",
        "pay.compLimitFree": "10 documents",
        "pay.compLimitPro": "Unlimited",
        "pay.compAI": "Apple Intelligence AI",
        "pay.compAIRec": "Basic (10 docs)",
        "pay.compAIRecPro": "Unlimited",
        "pay.compReminders": "Recurring Reminders",
        "pay.compRemindersFree": "One-time only",
        "pay.compRemindersPro": "Monthly / Quarterly / Yearly",
        "pay.compICloud": "iCloud Sync",
        "pay.compFaceID": "Face ID / Touch ID Lock",
        "pay.allInPro": "Everything in Pro:",
        "pay.feat1Title": "Unlimited Documents",
        "pay.feat1Sub": "No 10-document limit.",
        "pay.feat2Title": "Unlimited AI / Fair-Use",
        "pay.feat2Sub": "Process and analyze all your bills without restrictions.",
        "pay.feat3Title": "Advanced Categories",
        "pay.feat3Sub": "Passports, insurance, warranties, contracts, vehicles, home, etc.",
        "pay.feat4Title": "Smart Search & Smart Reminders",
        "pay.feat4Sub": "Locate any data in seconds and receive advanced alerts.",
        "pay.feat5Title": "Export & Encrypted Backup",
        "pay.feat5Sub": "Export your files and images to share easily.",
        "pay.feat6Title": "iCloud Sync & Notifications",
        "pay.feat6Sub": "Automatic backup in your private iCloud and secure local notifications.",
        "pay.secHeader": "Your security is our core priority",
        "pay.secSub": "iCloud Sync and Face ID protection are included in the base version of Life Admin.",
        "pay.btnSubscribe": "Subscribe to Pro — $3.99/mo",
        "pay.btnProActive": "Pro Subscription Active",
        "pay.btnRestore": "Restore Purchases",
        "pay.toggleTest": "Pro Testing Mode",
        "pay.disclaimer": "Subscription automatically renews monthly at $3.99/mo unless cancelled 24 hours before the end of the current period.",
        "pay.eula": "Terms of Use (EULA)",
        "pay.privacy": "Privacy Policy",
        "pay.prodMonthly": "Life Admin Pro Monthly",
        "pay.limitReachedTitle": "10 Document Limit Reached",
        "pay.limitReachedMsg": "Life Admin Base plan includes up to 10 documents. Subscribe to Pro for unlimited documents.",
        "pay.recOnlyPro": "Recurring reminders (monthly, quarterly, yearly) require Life Admin Pro.",
        "pay.catOnlyPro": "Advanced categories require Life Admin Pro.",

        // Onboarding
        "onb.p1Title": "Organized Documents and Bills",
        "onb.p1Msg": "Store bills in photos or PDF files in one place and find them quickly.",
        "onb.p2Title": "Dates and Recurring Reminders",
        "onb.p2Msg": "Receive automatic one-time or recurring notifications (monthly, quarterly, or yearly).",
        "onb.p3Title": "Private Protection",
        "onb.p3Msg": "Your images and data are analyzed on-device and backed up to your private iCloud.",
        "onb.btnSkip": "Skip",
        "onb.btnContinue": "Continue",
        "onb.btnStart": "Get Started",

        // Notifications
        "notif.dueTitle": "Payment Due: %@ (%@)",
        "notif.dueBody": "Bill '%@' for %@ is due today. Recurrence: %@",
        "notif.dueNoAmtTitle": "Document Expiration: %@",
        "notif.dueNoAmtBody": "Document '%@' expires or requires action today. Recurrence: %@",
        "notif.prevTitle": "Reminder: %@",
        "notif.prevBody": "Document '%@' will expire in 7 days.",

        // Authentication Gate & Account
        "gate.checking": "Checking your account…",
        "gate.sub": "Organize and protect your important documents.",
        "gate.appleBtnLabel": "Sign in with Apple",
        "gate.footer": "Your sign-in token is stored securely in Keychain. Sync uses device iCloud separately.",
        "acc.defaultName": "Apple Account",
        "acc.errInvalidCred": "Apple did not return a valid credential.",
        "acc.errKeychain": "Could not store session securely.",
        "acc.errCloudCheck": "Could not verify iCloud account.",
        "acc.errCloudUnknown": "Unknown iCloud status.",

        // Errors & Subscription
        "err.noText": "Could not recognize text in document.",
        "err.invalidImage": "Could not process one of the captured pages.",
        "sub.errFetch": "Could not load subscription plans from App Store Connect.",
        "sub.errRestore": "Could not restore purchases."
    ]

    static func string(for key: String, language: String) -> String {
        let dict = (language == "es") ? spanishStrings : englishStrings
        return dict[key] ?? key
    }
}
