import AuthenticationServices
import SwiftData
import SwiftUI
import VisionKit

struct ContentView: View {
    @Environment(AccountServices.self) private var accountServices
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var isAddingDocument = false
    @State private var isShowingOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView(showAddDocument: $isAddingDocument, selectedTab: $selectedTab)
            }

            Tab("Documents", systemImage: "doc.text.fill", value: 1) {
                DocumentLibraryView(showAddDocument: $isAddingDocument)
            }

            Tab("Upcoming", systemImage: "calendar.badge.clock", value: 2) {
                UpcomingView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: 3) {
                SettingsView(showOnboarding: $isShowingOnboarding)
            }
        }
        .tint(.indigo)
        .sheet(isPresented: $isAddingDocument) {
            AddDocumentView()
        }
        .sheet(isPresented: $isShowingOnboarding) {
            OnboardingView {
                hasCompletedOnboarding = true
                isShowingOnboarding = false
            }
        }
        .task {
            isShowingOnboarding = !hasCompletedOnboarding
            await accountServices.refresh()
        }
    }
}

private struct HomeView: View {
    @Environment(AccountServices.self) private var accountServices
    @Query(sort: \LifeDocument.createdAt, order: .reverse) private var documents: [LifeDocument]
    @Binding var showAddDocument: Bool
    @Binding var selectedTab: Int

    private var upcomingDocuments: [LifeDocument] {
        documents
            .filter { document in
                guard let date = document.expirationDate else { return false }
                return date >= Calendar.current.startOfDay(for: .now)
            }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    WelcomeHeader()
                    ProtectionBanner(status: accountServices.iCloudStatus == .available ? .protected : .localOnly)
                    QuickAddCard { showAddDocument = true }

                    if documents.isEmpty {
                        EmptyLibraryCard { showAddDocument = true }
                    } else {
                        DocumentSection(
                            title: "Coming up",
                            actionTitle: "View all",
                            documents: Array(upcomingDocuments.prefix(3))
                        ) {
                            selectedTab = 2
                        }

                        DocumentSection(
                            title: "Recently added",
                            actionTitle: "See library",
                            documents: Array(documents.prefix(4))
                        ) {
                            selectedTab = 1
                        }
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.08))
            .navigationTitle("Life Admin AI")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddDocument = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add document")
                }
            }
        }
    }
}

private struct WelcomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Good to have you here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Keep life’s important details under control.")
                .font(.title2.bold())
        }
    }
}

private struct ProtectionBanner: View {
    let status: ProtectionStatus

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: status.icon)
                .font(.title2)
                .foregroundStyle(status.color)
                .frame(width: 42, height: 42)
                .background(status.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(status.rawValue)
                    .font(.headline)
                Text(status == .protected ? "Los documentos se guardan localmente y se sincronizan con tu base privada de iCloud." : "Los documentos se guardan localmente hasta que iCloud esté disponible.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

private struct QuickAddCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "doc.viewfinder.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Add a document")
                        .font(.headline)
                    Text("Scan it and let Apple Intelligence complete the details on device.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: [.indigo, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyLibraryCard: View {
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Your documents live here", systemImage: "folder")
        } description: {
            Text("Add your first item to start tracking important details and dates.")
        } actions: {
            Button("Create document", action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct DocumentSection: View {
    let title: String
    let actionTitle: String
    let documents: [LifeDocument]
    let action: () -> Void

    var body: some View {
        if !documents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.title3.bold())
                    Spacer()
                    Button(actionTitle, action: action)
                        .font(.subheadline)
                }

                ForEach(documents) { document in
                    NavigationLink {
                        DocumentDetailView(document: document)
                    } label: {
                        DocumentRow(document: document)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DocumentLibraryView: View {
    @Query(sort: \LifeDocument.createdAt, order: .reverse) private var documents: [LifeDocument]
    @Binding var showAddDocument: Bool
    @State private var searchText = ""
    @State private var selectedCategory: DocumentCategory?

    private var filteredDocuments: [LifeDocument] {
        documents.filter { document in
            let categoryMatches = selectedCategory == nil || document.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatches = query.isEmpty || [
                document.title,
                document.issuer,
                document.ownerName,
                document.identifier,
                document.notes,
                document.category.rawValue
            ].contains { $0.localizedCaseInsensitiveContains(query) }
            return categoryMatches && searchMatches
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CategoryFilter(selectedCategory: $selectedCategory)

                if filteredDocuments.isEmpty {
                    ContentUnavailableView {
                        Label(
                            documents.isEmpty ? "No documents yet" : "No results",
                            systemImage: documents.isEmpty ? "doc.badge.plus" : "magnifyingglass"
                        )
                    } description: {
                        Text(documents.isEmpty ? "Create a local document to get started." : "Try another search or category.")
                    } actions: {
                        if documents.isEmpty {
                            Button("Add document") { showAddDocument = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    List(filteredDocuments) { document in
                        NavigationLink {
                            DocumentDetailView(document: document)
                        } label: {
                            DocumentRow(document: document)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Documents")
            .searchable(text: $searchText, prompt: "Title, issuer, owner or ID")
            .toolbar {
                Button {
                    showAddDocument = true
                } label: {
                    Label("Add document", systemImage: "plus")
                }
            }
        }
    }
}

private struct CategoryFilter: View {
    @Binding var selectedCategory: DocumentCategory?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(DocumentCategory.allCases) { category in
                    FilterChip(title: category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.indigo : Color.gray.opacity(0.12), in: Capsule())
    }
}

private struct DocumentRow: View {
    let document: LifeDocument

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: document.category.icon)
                .font(.title3)
                .foregroundStyle(document.category.color)
                .frame(width: 44, height: 44)
                .background(document.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(document.category.rawValue)
                    if let expirationDate = document.expirationDate {
                        Text("•")
                        Text(expirationDate, format: .dateTime.month(.abbreviated).day().year())
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: document.protectionStatus.icon)
                .foregroundStyle(document.protectionStatus.color)
                .accessibilityLabel(document.protectionStatus.rawValue)
        }
        .padding(.vertical, 5)
    }
}

private struct UpcomingView: View {
    @Query(sort: \LifeDocument.expirationDate) private var documents: [LifeDocument]
    @State private var horizon = 30

    private var upcomingDocuments: [LifeDocument] {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: horizon, to: start) ?? start
        return documents.filter {
            guard let expirationDate = $0.expirationDate else { return false }
            return expirationDate >= start && expirationDate <= end
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Time horizon", selection: $horizon) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .pickerStyle(.segmented)
                .padding()

                if upcomingDocuments.isEmpty {
                    ContentUnavailableView(
                        "Nothing due soon",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("Documents due in the next \(horizon) days will appear here.")
                    )
                } else {
                    List(upcomingDocuments) { document in
                        NavigationLink {
                            DocumentDetailView(document: document)
                        } label: {
                            DocumentRow(document: document)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Upcoming")
        }
    }
}

private struct AddDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountServices.self) private var accountServices

    @State private var title = ""
    @State private var category = DocumentCategory.personal
    @State private var issuer = ""
    @State private var ownerName = ""
    @State private var identifier = ""
    @State private var hasExpirationDate = true
    @State private var expirationDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var reminderEnabled = true
    @State private var notes = ""
    @State private var isShowingScanner = false
    @State private var isAnalyzingDocument = false
    @State private var analysisError: String?
    @State private var shouldOfferCameraSettings = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        Task {
                            await presentScanner()
                        }
                    } label: {
                        Label("Escanear y completar con Apple Intelligence", systemImage: "doc.viewfinder")
                    }
                    .disabled(isAnalyzingDocument)

                    if isAnalyzingDocument {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Leyendo y analizando el documento…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Captura inteligente")
                } footer: {
                    Text("La imagen y el texto se procesan en el dispositivo. Revisa los datos antes de guardar.")
                }

                Section("Document") {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(DocumentCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    TextField("Issuer", text: $issuer)
                    TextField("Owner or subject", text: $ownerName)
                    TextField("Identifier", text: $identifier)
                }

                Section {
                    Toggle("Has an expiration or action date", isOn: $hasExpirationDate)

                    if hasExpirationDate {
                        DatePicker("Date", selection: $expirationDate, displayedComponents: .date)
                        Toggle("Remind me", isOn: $reminderEnabled)
                    }
                } header: {
                    Text("Important date")
                } footer: {
                    Text("This date is entered and confirmed by you. Automatic notification scheduling will be added in the reminders milestone.")
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    if accountServices.iCloudStatus == .available {
                        Label("Guardado y preparado para sincronizar con iCloud", systemImage: "icloud")
                            .foregroundStyle(.blue)
                    } else {
                        Label("Guardado localmente hasta que iCloud esté disponible", systemImage: "iphone")
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    Text("SwiftData conserva una copia local y sincroniza automáticamente con la base privada de iCloud.")
                }
            }
            .navigationTitle("New Document")
            .fullScreenCover(isPresented: $isShowingScanner) {
                DocumentScannerView(
                    onComplete: { images in
                        isShowingScanner = false
                        analyze(images)
                    },
                    onCancel: {
                        isShowingScanner = false
                    },
                    onError: { error in
                        isShowingScanner = false
                        analysisError = error.localizedDescription
                    }
                )
                .ignoresSafeArea()
            }
            .alert(
                "No se pudo analizar el documento",
                isPresented: Binding(
                    get: { analysisError != nil },
                    set: { if !$0 { analysisError = nil } }
                )
            ) {
                if shouldOfferCameraSettings {
                    Button("Abrir Configuración") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(analysisError ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveDocument() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func presentScanner() async {
#if targetEnvironment(simulator)
        shouldOfferCameraSettings = false
        analysisError = "La cámara del simulador no puede escanear documentos y puede producir imágenes negras o verdes. Ejecuta la app directamente en un iPhone o iPad físico."
#else
        guard VNDocumentCameraViewController.isSupported else {
            shouldOfferCameraSettings = false
            analysisError = "El escáner requiere un iPhone o iPad físico compatible."
            return
        }

        switch await CameraAuthorization.requestAccess() {
        case .authorized:
            shouldOfferCameraSettings = false
            isShowingScanner = true
        case .denied:
            shouldOfferCameraSettings = true
            analysisError = "El acceso a la cámara está desactivado. Permítelo en Configuración para escanear documentos."
        case .restricted:
            shouldOfferCameraSettings = false
            analysisError = "El acceso a la cámara está restringido por el dispositivo."
        }
#endif
    }

    private func analyze(_ images: [UIImage]) {
        isAnalyzingDocument = true

        Task {
            do {
                let extracted = try await DocumentIntelligenceService.extract(from: images)
                apply(extracted)
            } catch {
                analysisError = error.localizedDescription
            }
            isAnalyzingDocument = false
        }
    }

    private func apply(_ extracted: ExtractedDocument) {
        title = extracted.title
        category = DocumentCategory.allCases.first {
            $0.rawValue.localizedCaseInsensitiveCompare(extracted.category) == .orderedSame
        } ?? .other
        issuer = extracted.issuer
        ownerName = extracted.ownerName
        identifier = extracted.identifier
        notes = extracted.notes

        if let extractedDate = extracted.expirationDate {
            expirationDate = extractedDate
            hasExpirationDate = true
        } else {
            hasExpirationDate = false
            reminderEnabled = false
        }
    }

    private func saveDocument() {
        let document = LifeDocument(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines),
            ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
            identifier: identifier.trimmingCharacters(in: .whitespacesAndNewlines),
            expirationDate: hasExpirationDate ? expirationDate : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            protectionStatus: accountServices.iCloudStatus == .available ? .syncPending : .localOnly,
            reminderEnabled: hasExpirationDate && reminderEnabled
        )
        modelContext.insert(document)
        dismiss()
    }
}

private struct DocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let document: LifeDocument
    @State private var isConfirmingDeletion = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: document.category.icon)
                        .font(.largeTitle)
                        .foregroundStyle(document.category.color)
                        .frame(width: 64, height: 64)
                        .background(document.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title)
                            .font(.title2.bold())
                        Text(document.category.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Protection") {
                Label(document.protectionStatus.rawValue, systemImage: document.protectionStatus.icon)
                    .foregroundStyle(document.protectionStatus.color)
                Text(document.protectionStatus == .localOnly ? "Este documento permanece en el dispositivo mientras iCloud no esté disponible." : "Este documento está preparado para sincronizarse con tu base privada de iCloud.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Details") {
                DetailValueRow(label: "Issuer", value: document.issuer)
                DetailValueRow(label: "Owner", value: document.ownerName)
                DetailValueRow(label: "Identifier", value: document.identifier)
                if let expirationDate = document.expirationDate {
                    LabeledContent("Action date") {
                        Text(expirationDate, format: .dateTime.month(.wide).day().year())
                    }
                    LabeledContent("Reminder", value: document.reminderEnabled ? "Requested" : "Off")
                }
                DetailValueRow(label: "Notes", value: document.notes)
            }

            Section {
                Button("Delete Document", role: .destructive) {
                    isConfirmingDeletion = true
                }
            }
        }
        .navigationTitle("Document")
        .confirmationDialog(
            "Delete this document?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(document)
                dismiss()
            }
        } message: {
            Text("This removes the local item and cannot be undone.")
        }
    }
}

private struct DetailValueRow: View {
    let label: String
    let value: String

    var body: some View {
        if !value.isEmpty {
            LabeledContent(label, value: value)
        }
    }
}

private struct SettingsView: View {
    @Environment(AccountServices.self) private var accountServices
    @Binding var showOnboarding: Bool
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("genericNotificationText") private var genericNotificationText = true

    var body: some View {
        NavigationStack {
            List {
                appleAccountSection
                iCloudSection

                Section("Privacidad y seguridad") {
                    Toggle("Bloqueo de la app", isOn: $appLockEnabled)
                    Toggle("Texto privado en notificaciones", isOn: $genericNotificationText)
                }

                Section("Acerca de") {
                    Button("Ver introducción") { showOnboarding = true }
                    LabeledContent("Versión", value: "0.2")
                    Link("Privacidad de Apple", destination: URL(string: "https://www.apple.com/privacy/")!)
                }

                Section {
                    Text("El escaneo, OCR y análisis con Apple Intelligence se realizan en el dispositivo. Los documentos se mantienen localmente y SwiftData los sincroniza con la base privada de iCloud cuando la cuenta está disponible.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Configuración")
            .task {
                await accountServices.refresh()
            }
        }
    }

    @ViewBuilder
    private var appleAccountSection: some View {
        Section {
            switch accountServices.appleSignInStatus {
            case .checking:
                HStack {
                    ProgressView()
                    Text("Verificando cuenta…")
                }
            case .signedOut:
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    accountServices.handleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .accessibilityLabel("Iniciar sesión con Apple")
            case .signedIn(let name):
                Label(name, systemImage: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(.green)
                Button("Cerrar sesión", role: .destructive) {
                    accountServices.signOut()
                }
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Button("Intentar de nuevo") {
                    Task {
                        await accountServices.refresh()
                    }
                }
            }
        } header: {
            Text("Cuenta de la app")
        } footer: {
            Text("Iniciar sesión con Apple identifica tu cuenta en la app. Apple solo comparte el nombre y correo la primera vez que autorizas.")
        }
    }

    @ViewBuilder
    private var iCloudSection: some View {
        Section {
            switch accountServices.iCloudStatus {
            case .checking:
                HStack {
                    ProgressView()
                    Text("Verificando iCloud…")
                }
            case .available:
                Label("Sincronización disponible", systemImage: "checkmark.icloud.fill")
                    .foregroundStyle(.green)
                Text("Los documentos se sincronizan con tu base privada de iCloud.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .noAccount:
                Label("No hay una cuenta de iCloud", systemImage: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Inicia sesión en iCloud desde Configuración del iPhone y activa iCloud Drive.")
                    .font(.footnote)
            case .restricted:
                Label("iCloud está restringido", systemImage: "lock.icloud")
                    .foregroundStyle(.orange)
            case .temporarilyUnavailable:
                Label("iCloud no está disponible temporalmente", systemImage: "exclamationmark.icloud")
                    .foregroundStyle(.orange)
            case .error(let message):
                Label(message, systemImage: "exclamationmark.icloud")
                    .foregroundStyle(.red)
            }

            Button("Actualizar estado") {
                Task {
                    await accountServices.refreshICloud()
                }
            }
        } header: {
            Text("Sincronización con iCloud")
        } footer: {
            Text("La cuenta de iCloud del dispositivo controla la sincronización y es independiente de Iniciar sesión con Apple.")
        }
    }
}

private struct OnboardingView: View {
    let completion: () -> Void
    @State private var page = 0

    private let pages = [
        OnboardingPage(
            icon: "doc.viewfinder",
            title: "Important documents, organized",
            message: "Keep personal, household and vehicle records together and find them quickly."
        ),
        OnboardingPage(
            icon: "calendar.badge.clock",
            title: "Know what needs attention",
            message: "Track confirmed expiration and action dates so nothing important gets lost."
        ),
        OnboardingPage(
            icon: "lock.icloud",
            title: "Protection you can understand",
            message: "The app always distinguishes cloud-protected data from items that exist only on this device."
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button("Skip", action: completion)
                }
            }
            .padding()

            VStack(spacing: 24) {
                Image(systemName: pages[page].icon)
                    .font(.system(size: 58))
                    .foregroundStyle(.indigo)
                    .frame(width: 120, height: 120)
                    .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 30))

                Text(pages[page].title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(pages[page].message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Color.indigo : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(32)
            .frame(maxHeight: .infinity)
            .contentTransition(.opacity)

            Button(page == pages.count - 1 ? "Get Started" : "Continue") {
                if page == pages.count - 1 {
                    completion()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let message: String
}

#Preview {
    ContentView()
        .modelContainer(for: LifeDocument.self, inMemory: true)
}
