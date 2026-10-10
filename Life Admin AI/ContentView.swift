import AuthenticationServices
import PDFKit
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

struct ContentView: View {
    @Environment(AccountServices.self) private var accountServices
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var languageManager = LanguageManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var isAddingDocument = false
    @State private var isShowingOnboarding = false
    @State private var isShowingPaywall = false

    @Query private var documents: [LifeDocument]

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(languageManager.tr("tab.home"), systemImage: "house.fill", value: 0) {
                HomeView(
                    showAddDocument: $isAddingDocument,
                    showPaywall: $isShowingPaywall,
                    selectedTab: $selectedTab
                )
            }

            Tab(languageManager.tr("tab.documents"), systemImage: "doc.text.fill", value: 1) {
                DocumentLibraryView(
                    showAddDocument: $isAddingDocument,
                    showPaywall: $isShowingPaywall
                )
            }

            Tab(languageManager.tr("tab.upcoming"), systemImage: "calendar.badge.clock", value: 2) {
                UpcomingView()
            }

            Tab(languageManager.tr("tab.settings"), systemImage: "gearshape.fill", value: 3) {
                SettingsView(
                    showOnboarding: $isShowingOnboarding,
                    showPaywall: $isShowingPaywall
                )
            }
        }
        .tint(.indigo)
        .environment(\.locale, languageManager.locale)
        .sheet(isPresented: $isAddingDocument) {
            AddDocumentView(showPaywallParent: $isShowingPaywall)
        }
        .sheet(isPresented: $isShowingOnboarding) {
            OnboardingView {
                hasCompletedOnboarding = true
                isShowingOnboarding = false
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
        .task {
            isShowingOnboarding = !hasCompletedOnboarding
            await accountServices.refresh()
            await subscriptionManager.updateSubscriptionStatus()
        }
    }
}

private struct HomeView: View {
    @Environment(AccountServices.self) private var accountServices
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var languageManager = LanguageManager.shared
    @Query(sort: \LifeDocument.createdAt, order: .reverse) private var documents: [LifeDocument]
    @Binding var showAddDocument: Bool
    @Binding var showPaywall: Bool
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

                    // Banner de plan Free / Pro
                    PlanBannerCard(
                        documentCount: documents.count,
                        isPro: subscriptionManager.isPro
                    ) {
                        showPaywall = true
                    }

                    // iCloud Sync y Protección de Datos
                    ProtectionBanner(status: accountServices.iCloudStatus == .available ? .protected : .localOnly)

                    QuickAddCard {
                        if subscriptionManager.canCreateDocument(currentCount: documents.count) {
                            showAddDocument = true
                        } else {
                            showPaywall = true
                        }
                    }

                    if documents.isEmpty {
                        EmptyLibraryCard {
                            if subscriptionManager.canCreateDocument(currentCount: documents.count) {
                                showAddDocument = true
                            } else {
                                showPaywall = true
                            }
                        }
                    } else {
                        DocumentSection(
                            title: languageManager.tr("home.sec.upcoming"),
                            actionTitle: languageManager.tr("home.sec.viewAll"),
                            documents: Array(upcomingDocuments.prefix(3))
                        ) {
                            selectedTab = 2
                        }

                        DocumentSection(
                            title: languageManager.tr("home.sec.recent"),
                            actionTitle: languageManager.tr("home.sec.viewLib"),
                            documents: Array(documents.prefix(4))
                        ) {
                            selectedTab = 1
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Life Admin AI")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if subscriptionManager.canCreateDocument(currentCount: documents.count) {
                            showAddDocument = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(languageManager.tr("doc.addBtn"))
                }
            }
        }
    }
}

private struct PlanBannerCard: View {
    @State private var languageManager = LanguageManager.shared
    let documentCount: Int
    let isPro: Bool
    let onUpgrade: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isPro ? languageManager.tr("home.plan.pro") : languageManager.tr("home.plan.free"))
                        .font(.headline)
                        .foregroundStyle(isPro ? Color.indigo : Color.primary)
                    if isPro {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Text(isPro ? languageManager.tr("home.plan.proDesc") : languageManager.tr("home.plan.freeDesc", documentCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isPro {
                Button(languageManager.tr("home.plan.getPro"), action: onUpgrade)
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)
            }
        }
        .padding()
        .background(isPro ? Color.indigo.opacity(0.15) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isPro ? Color.indigo.opacity(0.4) : Color(.separator), lineWidth: 1)
        )
    }
}

private struct ProtectionBanner: View {
    @State private var languageManager = LanguageManager.shared
    let status: ProtectionStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.icon)
                .font(.title2)
                .foregroundStyle(status.color)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(status.localizedName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(languageManager.tr("home.prot.freeIncluded"))
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }

                Text(status == .protected ? languageManager.tr("home.prot.descProtected") : languageManager.tr("home.prot.descLocal"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct WelcomeHeader: View {
    @State private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(languageManager.tr("home.welcome"))
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Text(languageManager.tr("home.subtitle"))
                .foregroundStyle(.secondary)
        }
    }
}

private struct QuickAddCard: View {
    @State private var languageManager = LanguageManager.shared
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "doc.badge.plus")
                    .font(.largeTitle)
                    .foregroundStyle(.indigo)
                    .frame(width: 56, height: 56)
                    .background(Color.indigo.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(languageManager.tr("home.quickAdd.title"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(languageManager.tr("home.quickAdd.desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyLibraryCard: View {
    @State private var languageManager = LanguageManager.shared
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.indigo)

            Text(languageManager.tr("home.empty.title"))
                .font(.headline)
                .foregroundStyle(.primary)

            Text(languageManager.tr("home.empty.desc"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(languageManager.tr("home.empty.button"), action: action)
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

private struct DocumentSection: View {
    let title: String
    let actionTitle: String
    let documents: [LifeDocument]
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Button(actionTitle, action: onSeeAll)
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
            }

            VStack(spacing: 10) {
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

private struct DocumentRow: View {
    let document: LifeDocument

    var body: some View {
        HStack(spacing: 14) {
            if let imageData = document.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: document.category.icon)
                    .font(.title3)
                    .foregroundStyle(document.category.color)
                    .frame(width: 44, height: 44)
                    .background(document.category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(document.category.localizedName)
                    if let expirationDate = document.expirationDate {
                        Text("•")
                        Text(expirationDate, format: .dateTime.month(.abbreviated).day())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let formattedAmount = document.formattedAmount {
                Text(formattedAmount)
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

private struct DocumentLibraryView: View {
    @State private var languageManager = LanguageManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @Query(sort: \LifeDocument.createdAt, order: .reverse) private var documents: [LifeDocument]

    @Binding var showAddDocument: Bool
    @Binding var showPaywall: Bool
    @State private var searchText = ""
    @State private var selectedCategory: DocumentCategory?

    private var filteredDocuments: [LifeDocument] {
        documents.filter { document in
            let matchesCategory = selectedCategory == nil || document.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty {
                return matchesCategory
            }
            let matchesTitle = document.title.localizedCaseInsensitiveContains(query)
            let matchesIssuer = document.issuer.localizedCaseInsensitiveContains(query)
            let matchesID = document.identifier.localizedCaseInsensitiveContains(query)
            let matchesAmount = document.formattedAmount?.localizedCaseInsensitiveContains(query) ?? false
            return matchesCategory && (matchesTitle || matchesIssuer || matchesID || matchesAmount)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                CategoryFilter(selectedCategory: $selectedCategory)

                if !searchText.isEmpty {
                    HStack {
                        Text(languageManager.tr("doc.resultsCount", filteredDocuments.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }

                if filteredDocuments.isEmpty {
                    ContentUnavailableView {
                        Label(
                            documents.isEmpty ? languageManager.tr("doc.emptyTitle") : languageManager.tr("doc.emptyNoResults"),
                            systemImage: documents.isEmpty ? "doc.badge.plus" : "magnifyingglass"
                        )
                    } description: {
                        Text(documents.isEmpty ? languageManager.tr("doc.emptyDesc") : languageManager.tr("doc.emptyResultsDesc"))
                    } actions: {
                        if documents.isEmpty {
                            Button(languageManager.tr("doc.addBtn")) {
                                if subscriptionManager.canCreateDocument(currentCount: documents.count) {
                                    showAddDocument = true
                                } else {
                                    showPaywall = true
                                }
                            }
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
            .navigationTitle(languageManager.tr("doc.title"))
            .searchable(text: $searchText, prompt: languageManager.tr("doc.searchPrompt"))
            .toolbar {
                Button {
                    if subscriptionManager.canCreateDocument(currentCount: documents.count) {
                        showAddDocument = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Label(languageManager.tr("doc.addBtn"), systemImage: "plus")
                }
            }
        }
    }
}

private struct CategoryFilter: View {
    @State private var languageManager = LanguageManager.shared
    @Binding var selectedCategory: DocumentCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: languageManager.tr("doc.filterAll"),
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(DocumentCategory.allCases) { cat in
                    FilterChip(
                        title: cat.localizedName,
                        isSelected: selectedCategory == cat
                    ) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .bold : .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.indigo : Color(.secondarySystemFill), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

private struct UpcomingView: View {
    @State private var languageManager = LanguageManager.shared
    @Query(sort: \LifeDocument.expirationDate, order: .forward) private var documents: [LifeDocument]
    @State private var selectedHorizon: HorizonFilter = .all

    private enum HorizonFilter: CaseIterable, Identifiable {
        case d30, d90, m6, y1, all

        var id: Self { self }

        func localizedName(in languageManager: LanguageManager) -> String {
            switch self {
            case .d30: return languageManager.tr("up.h30")
            case .d90: return languageManager.tr("up.h90")
            case .m6: return languageManager.tr("up.h6m")
            case .y1: return languageManager.tr("up.h1y")
            case .all: return languageManager.tr("up.hAll")
            }
        }

        var maxDate: Date? {
            let calendar = Calendar.current
            let now = Date.now
            switch self {
            case .d30: return calendar.date(byAdding: .day, value: 30, to: now)
            case .d90: return calendar.date(byAdding: .day, value: 90, to: now)
            case .m6: return calendar.date(byAdding: .month, value: 6, to: now)
            case .y1: return calendar.date(byAdding: .year, value: 1, to: now)
            case .all: return nil
            }
        }
    }

    private var datedDocuments: [LifeDocument] {
        documents.filter { $0.expirationDate != nil }
    }

    private var expiredDocuments: [LifeDocument] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return datedDocuments.filter { ($0.expirationDate ?? .now) < startOfToday }
    }

    private var filteredUpcomingDocuments: [LifeDocument] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return datedDocuments.filter { doc in
            guard let date = doc.expirationDate, date >= startOfToday else { return false }
            if let max = selectedHorizon.maxDate {
                return date <= max
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HorizonFilter.allCases) { horizon in
                            FilterChip(
                                title: horizon.localizedName(in: languageManager),
                                isSelected: selectedHorizon == horizon
                            ) {
                                selectedHorizon = horizon
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if expiredDocuments.isEmpty && filteredUpcomingDocuments.isEmpty {
                    ContentUnavailableView(
                        languageManager.tr("up.emptyTitle"),
                        systemImage: "calendar.badge.checkmark",
                        description: Text(languageManager.tr("up.emptyDesc"))
                    )
                } else {
                    List {
                        if !expiredDocuments.isEmpty {
                            Section(languageManager.tr("up.secExpired")) {
                                ForEach(expiredDocuments) { doc in
                                    NavigationLink {
                                        DocumentDetailView(document: doc)
                                    } label: {
                                        DocumentRow(document: doc)
                                    }
                                }
                            }
                        }

                        if !filteredUpcomingDocuments.isEmpty {
                            Section(languageManager.tr("up.secUpcoming", filteredUpcomingDocuments.count)) {
                                ForEach(filteredUpcomingDocuments) { doc in
                                    NavigationLink {
                                        DocumentDetailView(document: doc)
                                    } label: {
                                        DocumentRow(document: doc)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(languageManager.tr("up.title"))
        }
    }
}

private struct AddDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountServices.self) private var accountServices
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var languageManager = LanguageManager.shared
    @Query private var existingDocuments: [LifeDocument]

    var showPaywallParent: Binding<Bool>?

    init(showPaywallParent: Binding<Bool>? = nil) {
        self.showPaywallParent = showPaywallParent
    }

    @State private var title = ""
    @State private var category = DocumentCategory.personal
    @State private var issuer = ""
    @State private var ownerName = ""
    @State private var identifier = ""
    @State private var amountString = ""
    @State private var hasExpirationDate = true
    @State private var expirationDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var reminderEnabled = true
    @State private var recurrenceFrequency = RecurrenceFrequency.never
    @State private var notes = ""
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingFileImporter = false

    @State private var isShowingScanner = false
    @State private var isAnalyzingDocument = false
    @State private var analysisError: String?
    @State private var shouldOfferCameraSettings = false
    @State private var showLimitAlert = false
    @State private var showPaywallInternal = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                Button {
                                    Task {
                                        await presentScanner()
                                    }
                                } label: {
                                    Label(languageManager.tr("add.btnCamera"), systemImage: "doc.viewfinder")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isAnalyzingDocument)

                                PhotosPicker(
                                    selection: $selectedPhotoItem,
                                    matching: .images,
                                    photoLibrary: .shared()
                                ) {
                                    Label(languageManager.tr("add.btnPhoto"), systemImage: "photo.on.rectangle")
                                }
                                .buttonStyle(.bordered)
                                .disabled(isAnalyzingDocument)

                                Button {
                                    isShowingFileImporter = true
                                } label: {
                                    Label(languageManager.tr("add.btnPDF"), systemImage: "doc.badge.plus")
                                }
                                .buttonStyle(.bordered)
                                .disabled(isAnalyzingDocument)
                            }
                        }

                        if isAnalyzingDocument {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text(languageManager.tr("add.analyzing"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let selectedImage {
                            HStack(spacing: 12) {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(languageManager.tr("add.attachedTitle"))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(languageManager.tr("add.attachedSub"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    self.selectedImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(languageManager.tr("add.secScan"))
                }

                Section(languageManager.tr("add.secDetails")) {
                    TextField(languageManager.tr("add.lblTitle"), text: $title)

                    Picker(languageManager.tr("add.lblCat"), selection: $category) {
                        ForEach(DocumentCategory.allCases) { cat in
                            Label(cat.localizedName, systemImage: cat.icon).tag(cat)
                        }
                    }

                    TextField(languageManager.tr("add.lblIssuer"), text: $issuer)
                    TextField(languageManager.tr("add.lblOwner"), text: $ownerName)
                    TextField(languageManager.tr("add.lblID"), text: $identifier)

                    HStack {
                        Text(languageManager.tr("add.lblAmount"))
                        Spacer()
                        TextField("0.00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                }

                Section(languageManager.tr("add.secDates")) {
                    Toggle(languageManager.tr("add.toggleExpDate"), isOn: $hasExpirationDate)

                    if hasExpirationDate {
                        DatePicker(
                            languageManager.tr("add.lblDate"),
                            selection: $expirationDate,
                            displayedComponents: [.date]
                        )

                        Toggle(languageManager.tr("add.toggleReminder"), isOn: $reminderEnabled)

                        if reminderEnabled {
                            Picker(languageManager.tr("add.lblFreq"), selection: $recurrenceFrequency) {
                                ForEach(RecurrenceFrequency.allCases) { freq in
                                    HStack {
                                        Label(freq.localizedName, systemImage: freq.icon)
                                        if freq != .never && !subscriptionManager.isPro {
                                            Spacer()
                                            Text("PRO")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .tag(freq)
                                }
                            }
                            .onChange(of: recurrenceFrequency) { _, newFreq in
                                if newFreq != .never && !subscriptionManager.isPro {
                                    triggerPaywall()
                                    recurrenceFrequency = .never
                                }
                            }
                        }
                    }
                }

                Section(languageManager.tr("add.secNotes")) {
                    TextField(languageManager.tr("add.phNotes"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    if accountServices.iCloudStatus == .available {
                        Label(languageManager.tr("add.stCloud"), systemImage: "icloud")
                            .foregroundStyle(.blue)
                    } else {
                        Label(languageManager.tr("add.stLocal"), systemImage: "iphone")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(languageManager.tr("add.navTitle"))
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        analyze([uiImage])
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let fileURL = urls.first else { return }
                    processImportedFile(url: fileURL)
                case .failure(let error):
                    analysisError = error.localizedDescription
                }
            }
            .fullScreenCover(isPresented: $isShowingScanner) {
                DocumentScannerView(
                    onComplete: { images in
                        isShowingScanner = false
                        if let firstImage = images.first {
                            selectedImage = firstImage
                        }
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
                languageManager.tr("add.errTitle"),
                isPresented: Binding(
                    get: { analysisError != nil },
                    set: { if !$0 { analysisError = nil } }
                )
            ) {
                if shouldOfferCameraSettings {
                    Button(languageManager.tr("add.btnSettings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button(languageManager.tr("add.btnOK"), role: .cancel) {}
            } message: {
                Text(analysisError ?? "")
            }
            .alert(
                languageManager.tr("pay.limitReachedTitle"),
                isPresented: $showLimitAlert
            ) {
                Button(languageManager.tr("home.plan.getPro")) {
                    triggerPaywall()
                }
                Button(languageManager.tr("add.btnCancel"), role: .cancel) {}
            } message: {
                Text(languageManager.tr("pay.limitReachedMsg"))
            }
            .sheet(isPresented: $showPaywallInternal) {
                PaywallView()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageManager.tr("add.btnCancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.tr("add.btnSave")) { saveDocument() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func triggerPaywall() {
        if let parent = showPaywallParent {
            dismiss()
            parent.wrappedValue = true
        } else {
            showPaywallInternal = true
        }
    }

    private func processImportedFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            analysisError = "Permission denied."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        if url.pathExtension.lowercased() == "pdf" {
            if let pdfImage = convertPDFToImage(url: url) {
                selectedImage = pdfImage
                analyze([pdfImage])
            } else {
                analysisError = "Failed to process PDF."
            }
        } else if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            selectedImage = image
            analyze([image])
        }
    }

    private func convertPDFToImage(url: URL) -> UIImage? {
        guard let pdfDoc = PDFDocument(url: url), let page = pdfDoc.page(at: 0) else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    private func presentScanner() async {
#if targetEnvironment(simulator)
        shouldOfferCameraSettings = false
        analysisError = "Simulator camera unavailable."
#else
        guard VNDocumentCameraViewController.isSupported else {
            shouldOfferCameraSettings = false
            analysisError = "Document scanner requires a physical device."
            return
        }

        switch await CameraAuthorization.requestAccess() {
        case .authorized:
            shouldOfferCameraSettings = false
            isShowingScanner = true
        case .denied:
            shouldOfferCameraSettings = true
            analysisError = "Camera access denied."
        case .restricted:
            shouldOfferCameraSettings = false
            analysisError = "Camera access restricted."
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
        if !extracted.title.isEmpty { title = extracted.title }
        category = DocumentCategory.allCases.first {
            $0.rawValue.localizedCaseInsensitiveCompare(extracted.category) == .orderedSame ||
            $0.localizedName.localizedCaseInsensitiveCompare(extracted.category) == .orderedSame
        } ?? .other
        if !extracted.issuer.isEmpty { issuer = extracted.issuer }
        if !extracted.ownerName.isEmpty { ownerName = extracted.ownerName }
        if !extracted.identifier.isEmpty { identifier = extracted.identifier }
        if !extracted.notes.isEmpty { notes = extracted.notes }

        if let extractedAmount = extracted.amount {
            amountString = String(format: "%.2f", extractedAmount)
        }

        if subscriptionManager.isPro {
            recurrenceFrequency = extracted.recurrenceFrequency
        } else {
            recurrenceFrequency = .never
        }

        if let extractedDate = extracted.expirationDate {
            expirationDate = extractedDate
            hasExpirationDate = true
        }
    }

    private func saveDocument() {
        if !subscriptionManager.isPro && existingDocuments.count >= subscriptionManager.freeDocumentLimit {
            showLimitAlert = true
            return
        }

        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
        let parsedAmount = Double(amountString.replacingOccurrences(of: ",", with: "."))

        let finalFrequency = subscriptionManager.isPro ? recurrenceFrequency : .never

        let document = LifeDocument(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines),
            ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
            identifier: identifier.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: parsedAmount,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            protectionStatus: accountServices.iCloudStatus == .available ? .protected : .localOnly,
            reminderEnabled: hasExpirationDate && reminderEnabled,
            recurrenceFrequency: finalFrequency,
            imageData: imageData
        )
        modelContext.insert(document)

        if document.reminderEnabled {
            NotificationManager.scheduleReminder(for: document)
        }

        dismiss()
    }
}

private struct DocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var languageManager = LanguageManager.shared
    let document: LifeDocument
    @State private var isConfirmingDeletion = false
    @State private var isShowingFullImage = false
    @State private var showPaywall = false

    private var documentSummaryText: String {
        var text = "📄 Life Admin AI — \(document.title)\n"
        text += "• \(languageManager.tr("cat.\(document.category.rawValue)"))\n"
        if !document.issuer.isEmpty { text += "• \(languageManager.tr("det.lblIssuer")): \(document.issuer)\n" }
        if !document.ownerName.isEmpty { text += "• \(languageManager.tr("det.lblOwner")): \(document.ownerName)\n" }
        if !document.identifier.isEmpty { text += "• \(languageManager.tr("det.lblID")): \(document.identifier)\n" }
        if let amount = document.formattedAmount { text += "• \(languageManager.tr("det.lblAmount")): \(amount)\n" }
        if let exp = document.expirationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            text += "• \(languageManager.tr("det.lblExpDate")): \(formatter.string(from: exp))\n"
        }
        if !document.notes.isEmpty { text += "• \(languageManager.tr("det.lblNotes")): \(document.notes)\n" }
        return text
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    if let imageData = document.imageData, let uiImage = UIImage(data: imageData) {
                        Button {
                            isShowingFullImage = true
                        } label: {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )
                        }
                    } else {
                        Image(systemName: document.category.icon)
                            .font(.largeTitle)
                            .foregroundStyle(document.category.color)
                            .frame(width: 64, height: 64)
                            .background(document.category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 18))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title)
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                        Text(document.category.localizedName)
                            .foregroundStyle(.secondary)
                        if let formattedAmount = document.formattedAmount {
                            Text(formattedAmount)
                                .font(.headline)
                                .foregroundStyle(.indigo)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            if let imageData = document.imageData, let uiImage = UIImage(data: imageData) {
                Section(languageManager.tr("det.secAttached")) {
                    Button {
                        isShowingFullImage = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(languageManager.tr("det.previewTitle"))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text(languageManager.tr("add.attachedSub"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "eye.fill")
                                .font(.subheadline)
                                .foregroundStyle(.indigo)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Sección de Exportación y Compartir Documento
            Section {
                if let imageData = document.imageData, let uiImage = UIImage(data: imageData) {
                    ShareLink(
                        item: Image(uiImage: uiImage),
                        preview: SharePreview(document.title, image: Image(uiImage: uiImage))
                    ) {
                        Label(languageManager.tr("det.btnExport"), systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                            .foregroundStyle(.indigo)
                    }
                } else {
                    ShareLink(item: documentSummaryText) {
                        Label(languageManager.tr("det.btnExport"), systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                            .foregroundStyle(.indigo)
                    }
                }
            }

            Section(languageManager.tr("det.secDetails")) {
                DetailValueRow(label: languageManager.tr("det.lblIssuer"), value: document.issuer)
                DetailValueRow(label: languageManager.tr("det.lblOwner"), value: document.ownerName)
                DetailValueRow(label: languageManager.tr("det.lblID"), value: document.identifier)
                if let formattedAmount = document.formattedAmount {
                    LabeledContent(languageManager.tr("det.lblAmount")) {
                        Text(formattedAmount)
                            .font(.headline)
                            .foregroundStyle(.indigo)
                    }
                }
                if let expirationDate = document.expirationDate {
                    LabeledContent(languageManager.tr("det.lblExpDate")) {
                        Text(expirationDate, format: .dateTime.month(.wide).day().year())
                    }
                    Toggle(languageManager.tr("det.lblReminder"), isOn: Binding(
                        get: { document.reminderEnabled },
                        set: { newValue in
                            document.reminderEnabled = newValue
                            if newValue {
                                NotificationManager.scheduleReminder(for: document)
                            } else {
                                NotificationManager.cancelReminder(for: document)
                            }
                        }
                    ))
                    if document.reminderEnabled {
                        Picker(languageManager.tr("det.lblFreq"), selection: Binding(
                            get: { document.recurrenceFrequency },
                            set: { newFreq in
                                if newFreq != .never && !subscriptionManager.isPro {
                                    showPaywall = true
                                } else {
                                    document.recurrenceFrequency = newFreq
                                    NotificationManager.scheduleReminder(for: document)
                                }
                            }
                        )) {
                            ForEach(RecurrenceFrequency.allCases) { freq in
                                HStack {
                                    Label(freq.localizedName, systemImage: freq.icon)
                                    if freq != .never && !subscriptionManager.isPro {
                                        Spacer()
                                        Text("PRO")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .tag(freq)
                            }
                        }
                    }
                }
                DetailValueRow(label: languageManager.tr("det.lblNotes"), value: document.notes)
            }

            Section {
                Button(languageManager.tr("det.btnDelete"), role: .destructive) {
                    isConfirmingDeletion = true
                }
            }
        }
        .navigationTitle(languageManager.tr("det.navTitle"))
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $isShowingFullImage) {
            if let imageData = document.imageData, let uiImage = UIImage(data: imageData) {
                NavigationStack {
                    GeometryReader { proxy in
                        ZStack {
                            Color.black.ignoresSafeArea()
                            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                        }
                    }
                    .navigationTitle(languageManager.tr("det.previewTitle"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(languageManager.tr("det.btnClose")) { isShowingFullImage = false }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            languageManager.tr("det.dialogTitle"),
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button(languageManager.tr("det.btnDeleteConfirm"), role: .destructive) {
                deleteDocumentCompletely()
            }
        } message: {
            Text(languageManager.tr("det.dialogMsg"))
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let imageData = document.imageData, let uiImage = UIImage(data: imageData) {
                    ShareLink(
                        item: Image(uiImage: uiImage),
                        preview: SharePreview(document.title, image: Image(uiImage: uiImage))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    ShareLink(item: documentSummaryText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func deleteDocumentCompletely() {
        NotificationManager.cancelReminder(for: document)
        document.imageData = nil
        modelContext.delete(document)
        do {
            try modelContext.save()
        } catch {
            print("Error guardando contexto tras eliminación: \(error.localizedDescription)")
        }
        dismiss()
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var languageManager = LanguageManager.shared
    @Binding var showOnboarding: Bool
    @Binding var showPaywall: Bool
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    var body: some View {
        NavigationStack {
            List {
                Section(languageManager.tr("set.secPlan")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(subscriptionManager.isPro ? languageManager.tr("home.plan.pro") : languageManager.tr("home.plan.free"))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if subscriptionManager.isPro {
                                    Image(systemName: "crown.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                            Text(subscriptionManager.isPro ? languageManager.tr("set.planProDesc") : languageManager.tr("set.planFreeDesc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(subscriptionManager.isPro ? languageManager.tr("set.btnManage") : languageManager.tr("set.btnGetPro")) {
                            showPaywall = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

#if DEBUG
                    Toggle(languageManager.tr("set.toggleTesting"), isOn: Binding(
                        get: { subscriptionManager.isTestSubscriptionActive },
                        set: { _ in subscriptionManager.toggleTestSubscription() }
                    ))
                    .font(.subheadline)
#endif
                }

                Section(languageManager.tr("set.secLanguage")) {
                    Picker(languageManager.tr("set.pickerLanguage"), selection: Binding(
                        get: { languageManager.selectedLanguage },
                        set: { languageManager.selectedLanguage = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName(in: languageManager.selectedLanguage)).tag(lang)
                        }
                    }
                }

                appleAccountSection
                iCloudSection

                Section(languageManager.tr("set.secPrivacy")) {
                    Toggle(languageManager.tr("set.toggleLock"), isOn: Binding(
                        get: { appLockEnabled },
                        set: { newValue in
                            let reason = languageManager.tr("lock.reason")
                            BiometricHelper.verifyBiometrics(reason: reason) { success in
                                if success {
                                    appLockEnabled = newValue
                                }
                            }
                        }
                    ))
                }

                Section(languageManager.tr("set.secAbout")) {
                    Button(languageManager.tr("set.btnIntro")) { showOnboarding = true }
                    LabeledContent(languageManager.tr("set.lblVersion"), value: "1.1 (9)")
                    Link(languageManager.tr("set.linkPrivacy"), destination: URL(string: "https://www.apple.com/privacy/")!)
                }

                Section {
                    Text(languageManager.tr("set.footerDesc"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(languageManager.tr("set.title"))
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
                    Text(languageManager.tr("set.accChecking"))
                }
            case .signedIn(let name):
                HStack {
                    Label(
                        languageManager.tr("set.accSignedAs", name),
                        systemImage: "person.crop.circle.badge.checkmark"
                    )
                    .foregroundStyle(.green)
                    Spacer()
                    Button(languageManager.tr("set.accSignOut")) {
                        accountServices.signOut()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            case .signedOut, .error:
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    accountServices.handleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 44)
            }
        } header: {
            Text(languageManager.tr("set.secAccount"))
        } footer: {
            Text(languageManager.tr("set.accFooter"))
        }
    }

    @ViewBuilder
    private var iCloudSection: some View {
        Section {
            switch accountServices.iCloudStatus {
            case .checking:
                HStack {
                    ProgressView()
                    Text(languageManager.tr("set.cloudChecking"))
                }
            case .available:
                Label(languageManager.tr("set.cloudAvailable"), systemImage: "icloud.fill")
                    .foregroundStyle(.blue)
                Text(languageManager.tr("set.cloudAvailDesc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .noAccount:
                Label(languageManager.tr("set.cloudNoAccount"), systemImage: "icloud.slash")
                    .foregroundStyle(.orange)
                Text(languageManager.tr("set.cloudNoAccDesc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .restricted:
                Label(languageManager.tr("set.cloudRestricted"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            case .temporarilyUnavailable, .error:
                Label(languageManager.tr("set.cloudTempUnavail"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            Button(languageManager.tr("set.btnRefresh")) {
                Task { await accountServices.refresh() }
            }
            .font(.subheadline)
        } header: {
            Text(languageManager.tr("set.secICloud"))
        }
    }
}

private struct OnboardingView: View {
    @State private var languageManager = LanguageManager.shared
    let onDismiss: () -> Void

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button(languageManager.tr("onb.btnSkip"), action: onDismiss)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            TabView(selection: $currentPage) {
                OnboardingPage(
                    icon: "doc.viewfinder.fill",
                    title: languageManager.tr("onb.p1Title"),
                    description: languageManager.tr("onb.p1Msg")
                )
                .tag(0)

                OnboardingPage(
                    icon: "bell.badge.fill",
                    title: languageManager.tr("onb.p2Title"),
                    description: languageManager.tr("onb.p2Msg")
                )
                .tag(1)

                OnboardingPage(
                    icon: "shield.lock.fill",
                    title: languageManager.tr("onb.p3Title"),
                    description: languageManager.tr("onb.p3Msg")
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if currentPage < 2 {
                    withAnimation { currentPage += 1 }
                } else {
                    onDismiss()
                }
            } label: {
                Text(currentPage == 2 ? languageManager.tr("onb.btnStart") : languageManager.tr("onb.btnContinue"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

private struct OnboardingPage: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(.indigo)
                .frame(width: 120, height: 120)
                .background(Color.indigo.opacity(0.15), in: RoundedRectangle(cornerRadius: 30))

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
