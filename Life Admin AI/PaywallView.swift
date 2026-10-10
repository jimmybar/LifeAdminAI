import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var languageManager = LanguageManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.orange)
                            .frame(width: 88, height: 88)
                            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 22))

                        Text(languageManager.tr("pay.title"))
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)

                        Text(languageManager.tr("pay.price"))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.indigo)

                        Text(languageManager.tr("pay.sub"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Tabla Comparativa de Planes (Base vs Pro)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(languageManager.tr("pay.compareHeader"))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                        }

                        // Encabezados de Columna
                        HStack {
                            Text("")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(languageManager.tr("pay.planFreeTitle"))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 90, alignment: .center)
                            Text(languageManager.tr("pay.planProTitle"))
                                .font(.caption.bold())
                                .foregroundStyle(.indigo)
                                .frame(width: 100, alignment: .center)
                        }
                        .padding(.bottom, 2)

                        VStack(spacing: 12) {
                            ComparisonRow(
                                title: languageManager.tr("pay.compLimit"),
                                freeVal: languageManager.tr("pay.compLimitFree"),
                                proVal: languageManager.tr("pay.compLimitPro"),
                                isProHighlighted: true
                            )
                            Divider()
                            ComparisonRow(
                                title: languageManager.tr("pay.compReminders"),
                                freeVal: languageManager.tr("pay.compRemindersFree"),
                                proVal: languageManager.tr("pay.compRemindersPro"),
                                isProHighlighted: true
                            )
                            Divider()
                            ComparisonRow(
                                title: languageManager.tr("pay.compAI"),
                                freeVal: languageManager.tr("pay.compAIRec"),
                                proVal: languageManager.tr("pay.compAIRecPro"),
                                isProHighlighted: true
                            )
                            Divider()
                            ComparisonRow(
                                title: languageManager.tr("pay.compICloud"),
                                freeVal: "✓",
                                proVal: "✓",
                                isProHighlighted: false
                            )
                            Divider()
                            ComparisonRow(
                                title: languageManager.tr("pay.compFaceID"),
                                freeVal: "✓",
                                proVal: "✓",
                                isProHighlighted: false
                            )
                        }
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.separator), lineWidth: 1)
                    )

                    // Nota de Protección Base (Transparencia sobre lo que ya está incluido gratis)
                    HStack(spacing: 12) {
                        Image(systemName: "shield.checkmark.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(languageManager.tr("pay.secHeader"))
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text(languageManager.tr("pay.secSub"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                    // Selección de Producto / Botón de Compra
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            if subscriptionManager.products.isEmpty {
#if DEBUG
                                DummyPlanCard(
                                    price: languageManager.tr("pay.price"),
                                    isTestActive: subscriptionManager.isTestSubscriptionActive
                                ) {
                                    subscriptionManager.toggleTestSubscription()
                                }
#else
                                VStack(spacing: 6) {
                                    Text(languageManager.tr("pay.price"))
                                        .font(.title3.bold())
                                        .foregroundStyle(.indigo)
                                    Text(languageManager.tr("pay.prodMonthly"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
#endif
                            } else {
                                ForEach(subscriptionManager.products, id: \.id) { product in
                                    PlanOptionCard(
                                        product: product,
                                        isSelected: selectedProduct?.id == product.id
                                    ) {
                                        selectedProduct = product
                                    }
                                }
                            }
                        }
                    }

                    if let purchaseError {
                        Label(purchaseError, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    // Acciones de Compra y Restauración
                    VStack(spacing: 14) {
                        Button {
                            if let product = selectedProduct ?? subscriptionManager.products.first {
                                Task {
                                    isPurchasing = true
                                    defer { isPurchasing = false }
                                    do {
                                        let success = try await subscriptionManager.purchase(product)
                                        if success {
                                            dismiss()
                                        }
                                    } catch {
                                        purchaseError = error.localizedDescription
                                    }
                                }
                            } else {
#if DEBUG
                                subscriptionManager.toggleTestSubscription()
                                dismiss()
#endif
                            }
                        } label: {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(subscriptionManager.isPro ? languageManager.tr("pay.btnProActive") : languageManager.tr("pay.btnSubscribe"))
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(subscriptionManager.isPro ? Color.green : Color.indigo, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                        }
                        .disabled(isPurchasing)

                        VStack(spacing: 10) {
                            Button(languageManager.tr("pay.btnRestore")) {
                                Task {
                                    await subscriptionManager.restorePurchases()
                                    if subscriptionManager.isPro {
                                        dismiss()
                                    }
                                }
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(.indigo)

#if DEBUG
                            Toggle(languageManager.tr("pay.toggleTest"), isOn: Binding(
                                get: { subscriptionManager.isTestSubscriptionActive },
                                set: { _ in subscriptionManager.toggleTestSubscription() }
                            ))
                            .font(.subheadline)
                            .padding(.horizontal, 8)
#endif
                        }
                    }

                    // Enlaces requeridos por Apple Review Guidelines (3.1.2)
                    VStack(spacing: 6) {
                        Text(languageManager.tr("pay.disclaimer"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Link(languageManager.tr("pay.eula"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Text("•")
                                .foregroundStyle(.secondary)
                            Link(languageManager.tr("pay.privacy"), destination: URL(string: "https://www.apple.com/privacy/")!)
                        }
                        .font(.caption2.bold())
                        .foregroundStyle(.indigo)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageManager.tr("det.btnClose")) { dismiss() }
                }
            }
            .onAppear {
                if selectedProduct == nil {
                    selectedProduct = subscriptionManager.products.first
                }
            }
        }
    }
}

private struct ComparisonRow: View {
    let title: String
    let freeVal: String
    let proVal: String
    let isProHighlighted: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(freeVal)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .center)

            Text(proVal)
                .font(.caption.bold())
                .foregroundStyle(isProHighlighted ? Color.indigo : Color.primary)
                .frame(width: 100, alignment: .center)
        }
    }
}

#if DEBUG
private struct DummyPlanCard: View {
    let price: String
    let isTestActive: Bool
    let onToggleTest: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Life Admin Pro (Sandbox / Testing)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Activa la suscripción para realizar pruebas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(price)
                    .font(.title3.bold())
                    .foregroundStyle(.indigo)
            }

            Button {
                onToggleTest()
            } label: {
                Label(
                    isTestActive ? "Desactivar Modo Prueba Pro" : "Simular Compra Premium (Testing)",
                    systemImage: isTestActive ? "checkmark.circle.fill" : "cart.fill"
                )
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isTestActive ? Color.green.opacity(0.15) : Color.indigo.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(isTestActive ? Color.green : Color.indigo)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isTestActive ? Color.green : Color.indigo, lineWidth: 2)
        )
    }
}
#endif

private struct PlanOptionCard: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
            }
            .padding()
            .background(isSelected ? Color.indigo.opacity(0.15) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.indigo : Color(.separator), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}
