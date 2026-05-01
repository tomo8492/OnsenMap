import Foundation

// MARK: - Jalan Affiliate Config 拡張
extension AffiliateConfig {

    /// じゃらん net 検索 URL（※ アフィリエイト ID は valuecommerce / リクルートアフィリエイト経由）
    /// 取得: https://affiliate.valuecommerce.ne.jp/  もしくは https://af.recruit.co.jp/
    /// 形式例: ValueCommerce → "sid=12345&pid=67890"
    static let valueCommerceJalanQuery: String? = nil  // 例: "sid=3000000&pid=880000000"
}

// MARK: - Jalan Travel Service
/// じゃらん net への送客 URL を組み立てるサービス。
/// v1 では API ベースのインライン一覧は実装せず、検索URL→外部ブラウザ送客のみ対応。
/// (リクルート Webサービスは XML 応答のため、API 統合は v2 のフォローアップ)
final class JalanTravelService {

    static let shared = JalanTravelService()
    private init() {}

    /// 温泉名でじゃらん net を検索する URL を返す（温泉カテゴリの検索ページ）。
    /// ValueCommerce アフィリエイト設定があれば LinkSwitch 経由のラッパー URL を返す。
    func searchURL(for onsen: Onsen) -> URL {
        let kw = onsen.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? onsen.name
        let plain = "https://www.jalan.net/onsen/?keyword=\(kw)"
        return wrapWithAffiliateIfNeeded(plain)
    }

    /// 周辺エリア（lat/lon, 半径3km）でじゃらん net の宿を検索する URL を返す。
    func nearbySearchURL(for onsen: Onsen) -> URL {
        // 周辺地図検索 (uww1501init.do) — distance はメートル単位
        let plain = "https://www.jalan.net/uw/uwp1500/uww1501init.do?lat=\(onsen.latitude)&lon=\(onsen.longitude)&distance=3000"
        return wrapWithAffiliateIfNeeded(plain)
    }

    // MARK: - Affiliate Wrapping
    private func wrapWithAffiliateIfNeeded(_ plain: String) -> URL {
        guard let url = URL(string: plain) else {
            return URL(string: "https://www.jalan.net/onsen/")!
        }
        guard let vcQuery = AffiliateConfig.valueCommerceJalanQuery, !vcQuery.isEmpty,
              let dst = plain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return url
        }
        let wrapped = "https://ck.jp.ap.valuecommerce.com/servlet/referral?\(vcQuery)&vc_url=\(dst)"
        return URL(string: wrapped) ?? url
    }
}
