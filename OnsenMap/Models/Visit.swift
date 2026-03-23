import Foundation

// MARK: - Visit (日記エントリー)
struct Visit: Identifiable, Codable {
    let id: UUID
    var onsenId: UUID
    var onsenName: String          // キャッシュ用（onsen削除後も表示できるように）
    var date: Date
    var notes: String
    var rating: Int                // 1〜5 星
    var mood: Mood
    var companions: [String]       // 一緒に行った人
    var weather: Weather?
    var soakDurationMinutes: Int?  // 入浴時間（分）
    var photoFileNames: [String]   // ローカル保存した写真のファイル名

    // MARK: - Mood
    enum Mood: String, Codable, CaseIterable {
        case excellent = "最高"
        case good      = "良い"
        case average   = "普通"
        case poor      = "イマイチ"

        var icon: String {
            switch self {
            case .excellent: return "😄"
            case .good:      return "😊"
            case .average:   return "😐"
            case .poor:      return "😞"
            }
        }
    }

    // MARK: - Weather
    enum Weather: String, Codable, CaseIterable {
        case sunny  = "晴れ"
        case cloudy = "曇り"
        case rainy  = "雨"
        case snowy  = "雪"

        var icon: String {
            switch self {
            case .sunny:  return "☀️"
            case .cloudy: return "☁️"
            case .rainy:  return "🌧️"
            case .snowy:  return "❄️"
            }
        }
    }

    // MARK: Init
    init(
        id: UUID = UUID(),
        onsenId: UUID,
        onsenName: String,
        date: Date = Date(),
        notes: String = "",
        rating: Int = 3,
        mood: Mood = .good,
        companions: [String] = [],
        weather: Weather? = nil,
        soakDurationMinutes: Int? = nil,
        photoFileNames: [String] = []
    ) {
        self.id = id
        self.onsenId = onsenId
        self.onsenName = onsenName
        self.date = date
        self.notes = notes
        self.rating = rating
        self.mood = mood
        self.companions = companions
        self.weather = weather
        self.soakDurationMinutes = soakDurationMinutes
        self.photoFileNames = photoFileNames
    }
}
