import Foundation
import CoreLocation

// MARK: - Affiliate Config
/// アフィリエイト ID 等の中央設定。
/// 本番リリース前に各値を実際のIDに書き換えてください。
enum AffiliateConfig {

    /// 楽天デベロッパーで取得した Application ID
    /// 取得: https://webservice.rakuten.co.jp/app/create
    static let rakutenApplicationId: String? = nil  // 例: "1234567890123456789"

    /// 楽天アフィリエイト ID（成果報酬を受け取るために必須）
    /// 取得: https://affiliate.rakuten.co.jp/
    /// 形式例: "12345678.abcd1234.efgh5678"
    static let rakutenAffiliateId: String? = nil

    /// 楽天 API が利用可能か
    static var isRakutenConfigured: Bool {
        guard let appId = rakutenApplicationId, !appId.isEmpty else { return false }
        return true
    }
}

// MARK: - Rakuten Travel Hotel Model

struct RakutenHotel: Identifiable, Hashable {
    let id: Int                  // hotelNo
    let name: String
    let imageUrl: URL?
    let thumbnailUrl: URL?
    let address: String
    let access: String?
    let minCharge: Int?
    let reviewAverage: Double?
    let reviewCount: Int?
    let infoUrl: URL             // affiliateId 指定時はトラッキング付き URL
    let planListUrl: URL?
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Rakuten API Response (decoded)

private struct RakutenResponseRoot: Decodable {
    let hotels: [RakutenHotelEntry]?
}

private struct RakutenHotelEntry: Decodable {
    let hotel: [RakutenHotelInfoWrapper]
}

private struct RakutenHotelInfoWrapper: Decodable {
    let hotelBasicInfo: RakutenHotelBasicInfo?
}

private struct RakutenHotelBasicInfo: Decodable {
    let hotelNo: Int
    let hotelName: String
    let hotelInformationUrl: String
    let planListUrl: String?
    let hotelImageUrl: String?
    let hotelThumbnailUrl: String?
    let hotelMinCharge: Int?
    let address1: String?
    let address2: String?
    let access: String?
    let reviewAverage: Double?
    let reviewCount: Int?
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Rakuten Travel Service

/// 楽天トラベル「SimpleHotelSearch API」を使って、
/// 温泉の座標周辺の宿を取得するサービス。
final class RakutenTravelService {

    static let shared = RakutenTravelService()
    private init() {}

    private let endpoint = "https://app.rakuten.co.jp/services/api/Travel/SimpleHotelSearch/20170426"

    enum ServiceError: LocalizedError {
        case notConfigured
        case httpError(Int)
        case parseError
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "楽天 Application ID が未設定です"
            case .httpError(let code):
                return "通信エラー (HTTP \(code))"
            case .parseError:
                return "レスポンス解析に失敗しました"
            case .networkError(let e):
                return e.localizedDescription
            }
        }
    }

    /// 指定座標周辺のホテルを検索する
    /// - Parameters:
    ///   - center: 中心座標
    ///   - radiusKm: 検索半径（0.1 〜 3.0 km の範囲にクランプ）
    ///   - hits: 取得件数（最大30）
    func searchHotels(
        near center: CLLocationCoordinate2D,
        radiusKm: Double = 3.0,
        hits: Int = 10
    ) async throws -> [RakutenHotel] {

        guard let appId = AffiliateConfig.rakutenApplicationId, !appId.isEmpty else {
            throw ServiceError.notConfigured
        }

        let radius = max(0.1, min(3.0, radiusKm))
        let safeHits = max(1, min(30, hits))

        var components = URLComponents(string: endpoint)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "applicationId", value: appId),
            URLQueryItem(name: "format",        value: "json"),
            URLQueryItem(name: "latitude",      value: String(center.latitude)),
            URLQueryItem(name: "longitude",     value: String(center.longitude)),
            URLQueryItem(name: "searchRadius",  value: String(radius)),
            URLQueryItem(name: "datumType",     value: "1"),     // WGS84 (GPS)
            URLQueryItem(name: "hits",          value: String(safeHits)),
        ]
        if let affId = AffiliateConfig.rakutenAffiliateId, !affId.isEmpty {
            items.append(URLQueryItem(name: "affiliateId", value: affId))
        }
        components.queryItems = items

        guard let url = components.url else { throw ServiceError.parseError }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ServiceError.httpError(-1)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw ServiceError.httpError(http.statusCode)
            }
            let decoded = try JSONDecoder().decode(RakutenResponseRoot.self, from: data)
            return (decoded.hotels ?? []).compactMap { entry -> RakutenHotel? in
                guard let basic = entry.hotel.compactMap({ $0.hotelBasicInfo }).first,
                      let infoUrl = URL(string: basic.hotelInformationUrl) else {
                    return nil
                }
                let address = [basic.address1, basic.address2].compactMap { $0 }.joined()
                return RakutenHotel(
                    id: basic.hotelNo,
                    name: basic.hotelName,
                    imageUrl: basic.hotelImageUrl.flatMap { URL(string: $0) },
                    thumbnailUrl: basic.hotelThumbnailUrl.flatMap { URL(string: $0) },
                    address: address,
                    access: basic.access,
                    minCharge: basic.hotelMinCharge,
                    reviewAverage: basic.reviewAverage,
                    reviewCount: basic.reviewCount,
                    infoUrl: infoUrl,
                    planListUrl: basic.planListUrl.flatMap { URL(string: $0) },
                    latitude: basic.latitude,
                    longitude: basic.longitude
                )
            }
        } catch let error as ServiceError {
            throw error
        } catch is DecodingError {
            throw ServiceError.parseError
        } catch {
            throw ServiceError.networkError(error)
        }
    }

    /// API 未設定時 / API失敗時のフォールバック検索 URL。
    /// アフィリエイト ID があれば成果報酬対象 URL でラップする。
    func fallbackSearchURL(for onsen: Onsen) -> URL {
        let keyword = onsen.name
        let encodedKW = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        // 温泉特集ページのキーワード検索（楽天で 200 返すことを動作確認済み）
        let plain = "https://travel.rakuten.co.jp/onsen/?keyword=\(encodedKW)"

        if let affId = AffiliateConfig.rakutenAffiliateId, !affId.isEmpty,
           let pcEncoded = plain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            // hb.afl.rakuten.co.jp 経由でアフィリエイト計上
            let wrapped = "https://hb.afl.rakuten.co.jp/hgc/\(affId)/?pc=\(pcEncoded)"
            return URL(string: wrapped) ?? URL(string: plain)!
        }
        return URL(string: plain)!
    }
}
