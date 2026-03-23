import Foundation
import CoreLocation

// MARK: - Onsen Model
struct Onsen: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var nameReading: String        // ふりがな
    var address: String
    var prefecture: String
    var latitude: Double
    var longitude: Double
    var description: String
    var onsenType: OnsenType
    var springQuality: String?     // 泉質
    var facilities: [String]
    var phoneNumber: String?
    var website: String?
    var openingHours: String?
    var regularHoliday: String?    // 定休日
    var entryFee: String?
    var hasParking: Bool
    var imageNames: [String]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum OnsenType: String, Codable, CaseIterable {
        case hotSpring   = "温泉"
        case publicBath  = "銭湯"
        case spa         = "スパ"
        case resort      = "温泉リゾート"
        case dayUse      = "日帰り温泉"

        var icon: String {
            switch self {
            case .hotSpring:  return "♨️"
            case .publicBath: return "🛁"
            case .spa:        return "💆"
            case .resort:     return "🏨"
            case .dayUse:     return "🌊"
            }
        }

        var color: String {
            switch self {
            case .hotSpring:  return "orange"
            case .publicBath: return "blue"
            case .spa:        return "purple"
            case .resort:     return "green"
            case .dayUse:     return "cyan"
            }
        }
    }

    // MARK: Equatable / Hashable
    static func == (lhs: Onsen, rhs: Onsen) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: Init
    init(
        id: UUID = UUID(),
        name: String,
        nameReading: String = "",
        address: String,
        prefecture: String,
        latitude: Double,
        longitude: Double,
        description: String = "",
        onsenType: OnsenType = .hotSpring,
        springQuality: String? = nil,
        facilities: [String] = [],
        phoneNumber: String? = nil,
        website: String? = nil,
        openingHours: String? = nil,
        regularHoliday: String? = nil,
        entryFee: String? = nil,
        hasParking: Bool = true,
        imageNames: [String] = []
    ) {
        self.id = id
        self.name = name
        self.nameReading = nameReading
        self.address = address
        self.prefecture = prefecture
        self.latitude = latitude
        self.longitude = longitude
        self.description = description
        self.onsenType = onsenType
        self.springQuality = springQuality
        self.facilities = facilities
        self.phoneNumber = phoneNumber
        self.website = website
        self.openingHours = openingHours
        self.regularHoliday = regularHoliday
        self.entryFee = entryFee
        self.hasParking = hasParking
        self.imageNames = imageNames
    }
}
