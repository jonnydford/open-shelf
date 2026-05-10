import SwiftUI
import StoreKit

struct TipJarSection: View {
    @State private var store = TipJarStore()
    @State private var showThankYou = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Open Shelf is built by an independent developer. No ads, no tracking, no subscriptions \u{2014} just a reading app that respects your privacy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("If you enjoy the app, you can leave a tip to support continued development.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if store.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if store.products.isEmpty {
                Text("Tips unavailable \u{2014} check your connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.products, id: \.id) { product in
                    tipRow(product: product)
                }
            }

            if UserDefaults.standard.bool(forKey: "hasTipped") {
                Text("Thank you to everyone who has supported so far. \u{2665}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Support Open Shelf")
        }
        .task {
            await store.loadProducts()
        }
        .alert("Thank you!", isPresented: $showThankYou) {
            Button("OK") {}
        } message: {
            Text("Your support means the world. Thank you for helping keep Open Shelf going.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: store.purchaseState) { _, newState in
            switch newState {
            case .thanked:
                showThankYou = true
                store.purchaseState = .ready
            case .error(let message):
                errorMessage = message
                showError = true
                store.purchaseState = .ready
            default:
                break
            }
        }
    }

    private func tipRow(product: Product) -> some View {
        let tipProduct = TipProduct(rawValue: product.id)

        return HStack {
            if let tip = tipProduct {
                Image(systemName: tip.icon)
                    .foregroundStyle(iconColor(for: tip))
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tipProduct?.displayName ?? product.displayName)
                    .font(.subheadline)
                Text(product.displayPrice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await store.purchase(product)
                }
            } label: {
                Text("Tip")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(store.purchaseState == .purchasing)
        }
    }

    private func iconColor(for tip: TipProduct) -> Color {
        switch tip {
        case .small: .brown
        case .medium: .blue
        case .large: .red
        }
    }
}
