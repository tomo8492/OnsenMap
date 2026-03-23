import SwiftUI
import UIKit

// MARK: - Ad Banner View
/// Google AdMob バナー広告のラッパー
/// 実際に使うには GoogleMobileAds SDK をプロジェクトに追加してください。
/// 手順: https://developers.google.com/admob/ios/quick-start

// ──────────────────────────────────────────
// AdMob を有効化する場合は下記のコメントを外して
// GoogleMobileAds をインポートしてください
// ──────────────────────────────────────────
// import GoogleMobileAds

struct AdBannerView: View {
    // 本番用広告ユニットIDに差し替えてください
    // テスト用 ID: "ca-app-pub-3940256099942544/2934735716"
    let adUnitID: String

    var body: some View {
        // AdMob SDK が組み込まれたら下のプレースホルダーを
        // GADBannerViewRepresentable(adUnitID: adUnitID) に置き換えてください
        AdPlaceholderBanner()
    }
}

// MARK: - Placeholder（SDK未統合時の表示）
struct AdPlaceholderBanner: View {
    var body: some View {
        ZStack {
            Color(.systemGray6)
            HStack(spacing: 6) {
                Image(systemName: "megaphone.fill")
                    .foregroundStyle(.secondary)
                Text("広告スペース")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 50)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - GADBannerView Wrapper（AdMob SDK 追加後に使用）
/*
struct GADBannerViewRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
*/

// MARK: - Large Rectangle Ad (記事間広告)
struct AdRectangleView: View {
    var body: some View {
        ZStack {
            Color(.systemGray6)
            VStack(spacing: 4) {
                Image(systemName: "megaphone.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("広告")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 250)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
}
