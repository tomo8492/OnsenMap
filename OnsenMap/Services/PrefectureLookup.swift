import Foundation

// MARK: - Prefecture Lookup
/// 座標から都道府県名を推定するユーティリティ（OSM タグにない場合のフォールバック）
enum PrefectureLookup {

    struct PrefEntry {
        let name: String
        let south: Double; let north: Double
        let west: Double;  let east: Double
        func contains(lat: Double, lon: Double) -> Bool {
            lat >= south && lat <= north && lon >= west && lon <= east
        }
    }

    // 47都道府県のおおよそのバウンディングボックス
    static let prefectures: [PrefEntry] = [
        PrefEntry(name: "北海道",   south: 41.3,  north: 45.6,  west: 139.3, east: 145.9),
        PrefEntry(name: "青森県",   south: 40.2,  north: 41.6,  west: 139.3, east: 141.7),
        PrefEntry(name: "岩手県",   south: 38.7,  north: 40.5,  west: 140.5, east: 141.9),
        PrefEntry(name: "宮城県",   south: 37.7,  north: 39.0,  west: 140.2, east: 141.7),
        PrefEntry(name: "秋田県",   south: 38.8,  north: 40.5,  west: 139.7, east: 141.2),
        PrefEntry(name: "山形県",   south: 37.7,  north: 39.2,  west: 139.7, east: 140.8),
        PrefEntry(name: "福島県",   south: 36.8,  north: 37.9,  west: 139.1, east: 141.1),
        PrefEntry(name: "茨城県",   south: 35.7,  north: 36.8,  west: 139.7, east: 140.9),
        PrefEntry(name: "栃木県",   south: 36.2,  north: 37.2,  west: 139.3, east: 140.4),
        PrefEntry(name: "群馬県",   south: 36.1,  north: 37.0,  west: 138.4, east: 139.7),
        PrefEntry(name: "埼玉県",   south: 35.8,  north: 36.3,  west: 138.7, east: 139.9),
        PrefEntry(name: "千葉県",   south: 34.9,  north: 36.1,  west: 139.7, east: 140.9),
        PrefEntry(name: "東京都",   south: 24.0,  north: 35.9,  west: 136.0, east: 153.9), // 離島含む広域
        PrefEntry(name: "神奈川県", south: 35.1,  north: 35.7,  west: 138.9, east: 139.8),
        PrefEntry(name: "新潟県",   south: 36.8,  north: 38.6,  west: 137.6, east: 139.7),
        PrefEntry(name: "富山県",   south: 36.4,  north: 37.0,  west: 136.7, east: 137.7),
        PrefEntry(name: "石川県",   south: 36.1,  north: 37.9,  west: 136.1, east: 137.4),
        PrefEntry(name: "福井県",   south: 35.4,  north: 36.3,  west: 135.4, east: 136.8),
        PrefEntry(name: "山梨県",   south: 35.2,  north: 35.9,  west: 138.3, east: 139.2),
        PrefEntry(name: "長野県",   south: 35.2,  north: 37.0,  west: 137.3, east: 138.9),
        PrefEntry(name: "岐阜県",   south: 35.1,  north: 36.7,  west: 136.1, east: 137.7),
        PrefEntry(name: "静岡県",   south: 34.6,  north: 35.4,  west: 137.3, east: 139.2),
        PrefEntry(name: "愛知県",   south: 34.6,  north: 35.5,  west: 136.7, east: 137.9),
        PrefEntry(name: "三重県",   south: 33.7,  north: 35.0,  west: 135.8, east: 136.9),
        PrefEntry(name: "滋賀県",   south: 34.8,  north: 35.7,  west: 135.8, east: 136.5),
        PrefEntry(name: "京都府",   south: 34.7,  north: 35.8,  west: 134.9, east: 136.0),
        PrefEntry(name: "大阪府",   south: 34.2,  north: 35.0,  west: 135.1, east: 135.8),
        PrefEntry(name: "兵庫県",   south: 34.1,  north: 35.7,  west: 134.1, east: 135.6),
        PrefEntry(name: "奈良県",   south: 33.9,  north: 34.7,  west: 135.6, east: 136.2),
        PrefEntry(name: "和歌山県", south: 33.4,  north: 34.4,  west: 135.0, east: 136.1),
        PrefEntry(name: "鳥取県",   south: 35.0,  north: 35.6,  west: 133.1, east: 134.5),
        PrefEntry(name: "島根県",   south: 34.4,  north: 35.5,  west: 131.6, east: 133.4),
        PrefEntry(name: "岡山県",   south: 34.5,  north: 35.3,  west: 133.2, east: 134.6),
        PrefEntry(name: "広島県",   south: 34.0,  north: 35.2,  west: 132.0, east: 133.5),
        PrefEntry(name: "山口県",   south: 33.8,  north: 34.8,  west: 130.7, east: 132.3),
        PrefEntry(name: "徳島県",   south: 33.5,  north: 34.3,  west: 133.6, east: 134.8),
        PrefEntry(name: "香川県",   south: 34.1,  north: 34.6,  west: 133.4, east: 134.3),
        PrefEntry(name: "愛媛県",   south: 32.9,  north: 34.1,  west: 132.2, east: 133.8),
        PrefEntry(name: "高知県",   south: 32.7,  north: 33.9,  west: 132.5, east: 134.3),
        PrefEntry(name: "福岡県",   south: 33.0,  north: 34.3,  west: 130.0, east: 131.1),
        PrefEntry(name: "佐賀県",   south: 32.8,  north: 33.6,  west: 129.7, east: 130.6),
        PrefEntry(name: "長崎県",   south: 31.9,  north: 34.7,  west: 128.3, east: 130.1),
        PrefEntry(name: "熊本県",   south: 32.0,  north: 33.2,  west: 130.0, east: 131.3),
        PrefEntry(name: "大分県",   south: 32.8,  north: 33.7,  west: 130.7, east: 132.0),
        PrefEntry(name: "宮崎県",   south: 31.4,  north: 32.9,  west: 130.6, east: 131.9),
        PrefEntry(name: "鹿児島県", south: 27.0,  north: 32.0,  west: 129.2, east: 131.2),
        PrefEntry(name: "沖縄県",   south: 24.0,  north: 27.5,  west: 122.9, east: 131.4),
    ]

    /// 座標から都道府県名を返す。一致しなければ "日本" を返す。
    static func lookup(lat: Double, lon: Double) -> String {
        // 精度の高い（面積の小さい）都道府県を先にマッチさせる
        let sorted = prefectures.sorted {
            let a0 = ($0.north - $0.south) * ($0.east - $0.west)
            let b0 = ($1.north - $1.south) * ($1.east - $1.west)
            return a0 < b0
        }
        return sorted.first { $0.contains(lat: lat, lon: lon) }?.name ?? "日本"
    }
}
