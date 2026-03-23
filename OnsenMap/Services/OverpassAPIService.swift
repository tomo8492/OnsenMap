import Foundation
import CoreLocation

// MARK: - Overpass API Response Models

struct OverpassResponse: Codable {
    let elements: [OverpassElement]
}

struct OverpassElement: Codable {
    let id: Int64
    let type: String
    let lat: Double?
    let lon: Double?
    let center: OverpassCenter?
    let tags: [String: String]?

    var latitude:  Double? { lat ?? center?.lat }
    var longitude: Double? { lon ?? center?.lon }
}

struct OverpassCenter: Codable {
    let lat: Double
    let lon: Double
}

// MARK: - Overpass API Service

/// OpenStreetMap の Overpass API から日本全国の温泉・公衆浴場データを取得するサービス
actor OverpassAPIService {

    static let shared = OverpassAPIService()
    private init() {}

    private let baseURL = "https://overpass-api.de/api/interpreter"

    // MARK: - Fetch All Japan

    /// 日本全国の温泉・公衆浴場を全取得する（約2500〜3000件）
    func fetchAllJapanOnsens(
        progressHandler: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> [Onsen] {

        // 都道府県ごとに分割して取得（タイムアウト防止）
        var allOnsens: [Onsen] = []
        let regions = JapanRegion.allRegions

        for (index, region) in regions.enumerated() {
            do {
                let batch = try await fetchRegion(region)
                allOnsens.append(contentsOf: batch)
                progressHandler?(index + 1, regions.count)
                // API 負荷軽減のため少し待つ
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                // 個別リージョンのエラーは無視して続行
                print("⚠️ Region \(region.name) fetch failed: \(error)")
            }
        }

        // 重複除去（同一座標 ±0.001度以内）
        return deduplicateOnsens(allOnsens)
    }

    // MARK: - Fetch by Bounding Box (近傍検索)

    /// 指定した中心座標から半径 radiusKm km 以内の温泉を取得する
    func fetchNearby(
        center: CLLocationCoordinate2D,
        radiusKm: Double = 10
    ) async throws -> [Onsen] {
        let delta = radiusKm / 111.0  // 1度 ≈ 111km
        let bbox = BoundingBox(
            south: center.latitude  - delta,
            north: center.latitude  + delta,
            west:  center.longitude - delta,
            east:  center.longitude + delta
        )
        return try await fetchBBox(bbox)
    }

    // MARK: - Internal fetch helpers

    private func fetchRegion(_ region: JapanRegion) async throws -> [Onsen] {
        let results = try await fetchBBox(region.bbox)
        return results
    }

    private func fetchBBox(_ bbox: BoundingBox) async throws -> [Onsen] {
        let bboxStr = "\(bbox.south),\(bbox.west),\(bbox.north),\(bbox.east)"

        // 秘湯・一般温泉・公衆浴場・入浴施設をすべて網羅するクエリ
        let query = """
        [out:json][timeout:90];
        (
          node["natural"="hot_spring"](\(bboxStr));
          node["amenity"="public_bath"](\(bboxStr));
          node["amenity"="spa"](\(bboxStr));
          node["leisure"="bathing_place"](\(bboxStr));
          way["natural"="hot_spring"](\(bboxStr));
          way["amenity"="public_bath"](\(bboxStr));
          way["amenity"="spa"](\(bboxStr));
          way["leisure"="bathing_place"](\(bboxStr));
        );
        out center tags;
        """

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw OverpassError.httpError
        }

        let overpassResponse = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return overpassResponse.elements.compactMap { parseElement($0) }
    }

    // MARK: - Parse OSM Element → Onsen

    private func parseElement(_ element: OverpassElement) -> Onsen? {
        guard let lat  = element.latitude,
              let lon  = element.longitude,
              let tags = element.tags else { return nil }

        // 名前（日本語優先）
        let name = tags["name:ja"] ?? tags["name"] ?? tags["name:en"] ?? tags["name:ja-Hrkt"]
        guard let name = name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        // 泉質タグ判定
        let naturalTag  = tags["natural"]  ?? ""
        let amenityTag  = tags["amenity"]  ?? ""
        let leisureTag  = tags["leisure"]  ?? ""
        let bathType    = tags["bath:type"] ?? ""

        let onsenType: Onsen.OnsenType = {
            if naturalTag == "hot_spring"            { return .hotSpring }
            if amenityTag == "public_bath" {
                if bathType == "onsen"               { return .hotSpring }
                if bathType == "mineral_bath"        { return .hotSpring }
                                                       return .publicBath
            }
            if amenityTag == "spa"                   { return .spa }
            if leisureTag == "bathing_place"         { return .dayUse }
            return .hotSpring
        }()

        // 住所組み立て
        let pref    = tags["addr:prefecture"] ?? tags["addr:state"]
                      ?? PrefectureLookup.lookup(lat: lat, lon: lon)
        let city    = tags["addr:city"]    ?? tags["addr:town"]   ?? tags["addr:village"] ?? ""
        let suburb  = tags["addr:suburb"]  ?? tags["addr:quarter"] ?? ""
        let street  = tags["addr:full"]    ?? tags["addr:street"]  ?? ""
        let addr    = [pref, city, suburb, street].filter { !$0.isEmpty }.joined()

        // 施設リスト（OSM タグから推定）
        var facilities: [String] = []
        if tags["sauna"]            == "yes" { facilities.append("サウナ") }
        if tags["outdoor_seating"]  == "yes" { facilities.append("露天風呂") }
        if tags["swimming_pool"]    == "yes" { facilities.append("プール") }
        if tags["wheelchair"]       == "yes" { facilities.append("バリアフリー") }
        if tags["parking"]          == "yes" || tags["parking:fee"] != nil {
            facilities.append("駐車場")
        }

        // 秘湯判定: 自然源泉 かつ 施設名・運営者なし かつ アクセス困難
        let isSecretOnsen = (naturalTag == "hot_spring")
            && tags["operator"] == nil
            && tags["tourism"]  == nil
            && tags["fee"]      == nil
        if isSecretOnsen {
            facilities.insert("秘湯", at: 0)
        }

        // 泉質
        let springQuality = tags["onsen:spring_type"]
            ?? tags["mineral_spring:name"]
            ?? tags["spring:type"]

        // 料金
        let entryFee: String?
        if tags["fee"] == "no"  { entryFee = "無料" }
        else if tags["fee"] == "yes" { entryFee = "有料（金額不明）" }
        else { entryFee = nil }

        return Onsen(
            name:          name,
            nameReading:   tags["name:ja-Hrkt"] ?? tags["name:ja-Hira"] ?? "",
            address:       addr.isEmpty ? "\(pref)（詳細住所不明）" : addr,
            prefecture:    pref,
            latitude:      lat,
            longitude:     lon,
            description:   tags["description:ja"] ?? tags["description"]
                           ?? (isSecretOnsen
                               ? "自然湧出の秘湯です。アクセスにご注意ください。"
                               : ""),
            onsenType:     onsenType,
            springQuality: springQuality,
            facilities:    facilities,
            phoneNumber:   tags["phone"] ?? tags["contact:phone"],
            website:       tags["website"] ?? tags["contact:website"] ?? tags["url"],
            openingHours:  tags["opening_hours"],
            regularHoliday: nil,
            entryFee:      entryFee,
            hasParking:    tags["parking"] == "yes"
        )
    }

    // MARK: - Deduplication

    private func deduplicateOnsens(_ onsens: [Onsen]) -> [Onsen] {
        var seen: [(Double, Double)] = []
        return onsens.filter { onsen in
            let hasDuplicate = seen.contains {
                abs($0.0 - onsen.latitude) < 0.0005 && abs($0.1 - onsen.longitude) < 0.0005
            }
            if hasDuplicate { return false }
            seen.append((onsen.latitude, onsen.longitude))
            return true
        }
    }

    // MARK: - Errors
    enum OverpassError: LocalizedError {
        case httpError
        case parseError

        var errorDescription: String? {
            switch self {
            case .httpError:  return "サーバーとの通信に失敗しました。"
            case .parseError: return "データの解析に失敗しました。"
            }
        }
    }
}

// MARK: - Bounding Box

struct BoundingBox {
    let south: Double
    let north: Double
    let west:  Double
    let east:  Double
}

// MARK: - Japan Regions（都道府県グループ）

struct JapanRegion {
    let name: String
    let bbox: BoundingBox

    /// 日本全国を8リージョンに分割（Overpass API タイムアウト回避）
    static let allRegions: [JapanRegion] = [
        JapanRegion(name: "北海道",
                    bbox: BoundingBox(south: 41.3, north: 45.6, west: 139.3, east: 145.9)),
        JapanRegion(name: "東北",
                    bbox: BoundingBox(south: 36.9, north: 41.6, west: 138.9, east: 142.1)),
        JapanRegion(name: "関東",
                    bbox: BoundingBox(south: 34.9, north: 37.0, west: 138.5, east: 140.9)),
        JapanRegion(name: "中部",
                    bbox: BoundingBox(south: 34.5, north: 37.9, west: 136.0, east: 139.8)),
        JapanRegion(name: "近畿",
                    bbox: BoundingBox(south: 33.5, north: 36.2, west: 134.2, east: 137.0)),
        JapanRegion(name: "中国・四国",
                    bbox: BoundingBox(south: 32.7, north: 35.5, west: 130.5, east: 134.6)),
        JapanRegion(name: "九州",
                    bbox: BoundingBox(south: 30.9, north: 34.0, west: 129.5, east: 132.0)),
        JapanRegion(name: "沖縄",
                    bbox: BoundingBox(south: 24.0, north: 27.5, west: 122.9, east: 131.4)),
    ]
}
