import SwiftUI
import StoreKit

// MARK: - Paywall View
/// OnsenMap Pro の購入画面（買い切り型）
struct PaywallView: View {
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseError: String?
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featuresSection
                    purchaseSection
                    secondaryActions
                    footnote
                }
                .padding()
            }
            .navigationTitle("OnsenMap Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await store.loadProducts() }
        }
    }

    // MARK: - Sections
    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }
            .padding(.top, 12)

            Text("OnsenMap Pro")
                .font(.largeTitle).fontWeight(.bold)

            Text("一度の購入で永続的にすべての特典を解放")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProFeatureRow(icon: "rectangle.slash.fill", title: "広告非表示",
                          subtitle: "バナー・インタースティシャルをすべてオフ")
            ProFeatureRow(icon: "photo.stack.fill", title: "写真無制限",
                          subtitle: "1記録あたりの写真枚数制限を解除")
            ProFeatureRow(icon: "icloud.fill", title: "iCloud 同期",
                          subtitle: "複数端末で記録を同期（無料機能）")
            ProFeatureRow(icon: "square.and.arrow.up.fill", title: "CSV エクスポート",
                          subtitle: "全記録を CSV で保存・共有")
            ProFeatureRow(icon: "chart.bar.fill", title: "詳細統計",
                          subtitle: "年別・月別・泉質別の入浴傾向")
            ProFeatureRow(icon: "heart.fill", title: "個人開発者の応援",
                          subtitle: "アップデートを継続できます")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if store.isPro {
                Label("Pro を購入済みです！", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else if let product = store.lifetimeProProduct {
                Button {
                    Task { await purchase(product) }
                } label: {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "crown.fill")
                        }
                        Text(isProcessing ? "処理中..." : "Pro を購入  \(product.displayPrice)")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            } else if store.isLoadingProducts {
                ProgressView("商品情報を取得中...")
            } else {
                Text("商品情報を取得できませんでした")
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("再試行") {
                    Task { await store.loadProducts() }
                }
                .font(.subheadline)
            }

            if let err = purchaseError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var secondaryActions: some View {
        VStack(spacing: 8) {
            Button("購入を復元") {
                Task { await store.restorePurchases() }
            }
            .font(.subheadline)
            .foregroundStyle(.orange)

            HStack(spacing: 16) {
                Link("利用規約", destination: URL(string: "https://example.com/terms")!)
                Link("プライバシーポリシー", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var footnote: some View {
        Text("一度きりの買い切り。サブスクリプションではありません。")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    // MARK: - Purchase Flow
    private func purchase(_ product: Product) async {
        isProcessing = true
        defer { isProcessing = false }
        let result = await store.purchase(product)
        switch result {
        case .success:
            purchaseError = nil
            dismiss()
        case .userCancelled:
            break
        case .pending:
            purchaseError = "決済が承認待ちです。承認後に自動で反映されます。"
        case .failed(let msg):
            purchaseError = msg
        }
    }
}

// MARK: - Pro Feature Row
struct ProFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 30, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
