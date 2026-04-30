import Foundation
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - Interstitial Ad Manager
/// AdMob インタースティシャル広告（称号アップグレード時などのお祝い演出と相性が良い）
/// - Pro ユーザーには出さない
/// - 表示後に自動でプリロード
/// - GoogleMobileAds SDK が未統合の環境ではスタブ動作
@MainActor
final class InterstitialAdManager: NSObject, ObservableObject {

    static let shared = InterstitialAdManager()

    // MARK: - Ad Unit IDs
    /// テスト用 ID（Google公式）— 開発中は常にこちらを使う
    private static let testAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    /// 本番用 ID（リリース前に書き換え）
    private static let productionAdUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"

    private var adUnitID: String {
        #if DEBUG
        return Self.testAdUnitID
        #else
        return Self.productionAdUnitID
        #endif
    }

    // MARK: - State
    @Published private(set) var isReady = false

    /// 表示間隔の制御（同一セッション内で連続表示しない）
    private var lastPresentedAt: Date?
    private let minimumIntervalSeconds: TimeInterval = 90

    #if canImport(GoogleMobileAds)
    private var loadedAd: GADInterstitialAd?
    #endif

    private override init() {
        super.init()
    }

    // MARK: - Preload
    /// 次の表示用に広告をプリロードする。Pro ユーザーには何もしない。
    func preload() {
        guard !StoreManager.shared.isPro else { return }
        #if canImport(GoogleMobileAds)
        Task {
            do {
                let ad = try await GADInterstitialAd.load(
                    withAdUnitID: adUnitID,
                    request: GADRequest()
                )
                ad.fullScreenContentDelegate = self
                loadedAd = ad
                isReady = true
            } catch {
                isReady = false
                print("⚠️ Interstitial load failed: \(error.localizedDescription)")
            }
        }
        #endif
    }

    // MARK: - Show
    /// 準備済みなら表示する。Pro ユーザー or 直近表示済みの場合は何もしない。
    func showIfReady() {
        guard !StoreManager.shared.isPro else { return }
        if let last = lastPresentedAt, Date().timeIntervalSince(last) < minimumIntervalSeconds {
            return
        }
        #if canImport(GoogleMobileAds)
        guard let ad = loadedAd,
              let rootVC = currentRootViewController() else {
            return
        }
        ad.present(fromRootViewController: rootVC)
        lastPresentedAt = Date()
        loadedAd = nil
        isReady = false
        // 次回用に再ロード
        preload()
        #endif
    }

    // MARK: - Helpers
    private func currentRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return nil
        }
        return scene.windows.first(where: \.isKeyWindow)?.rootViewController
    }
}

#if canImport(GoogleMobileAds)
extension InterstitialAdManager: GADFullScreenContentDelegate {
    // SDK からのデリゲートコールバックは任意のスレッドから呼ばれる可能性があるため、
    // nonisolated にしておき、MainActor で再ディスパッチする
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in self.preload() }
    }
    nonisolated func ad(_ ad: GADFullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        print("⚠️ Interstitial present failed: \(error.localizedDescription)")
        Task { @MainActor in self.preload() }
    }
}
#endif
