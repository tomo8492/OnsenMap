import Foundation
import Combine

// MARK: - Persistence Service
/// UserDefaults + JSON を使ったシンプルな永続化サービス
final class PersistenceService {

    static let shared = PersistenceService()
    private init() {}

    private let defaults = UserDefaults.standard

    // Keys
    private enum Key {
        static let visits           = "onsenmap.visits"
        static let customOnsens     = "onsenmap.customOnsens"
        static let visitedIds       = "onsenmap.visitedIds"
        static let userName         = "onsenmap.userName"
        static let userBadges       = "onsenmap.userBadges"
        static let customDisplayTitle = "onsenmap.customDisplayTitle"
    }

    // MARK: - Visits
    func saveVisits(_ visits: [Visit]) {
        if let data = try? JSONEncoder().encode(visits) {
            defaults.set(data, forKey: Key.visits)
        }
    }

    func loadVisits() -> [Visit] {
        guard let data = defaults.data(forKey: Key.visits),
              let visits = try? JSONDecoder().decode([Visit].self, from: data) else {
            return []
        }
        return visits
    }

    // MARK: - Custom Onsens (ユーザーが追加した温泉)
    func saveCustomOnsens(_ onsens: [Onsen]) {
        if let data = try? JSONEncoder().encode(onsens) {
            defaults.set(data, forKey: Key.customOnsens)
        }
    }

    func loadCustomOnsens() -> [Onsen] {
        guard let data = defaults.data(forKey: Key.customOnsens),
              let onsens = try? JSONDecoder().decode([Onsen].self, from: data) else {
            return []
        }
        return onsens
    }

    // MARK: - Visited Onsen IDs
    func saveVisitedIds(_ ids: Set<UUID>) {
        let strings = ids.map { $0.uuidString }
        defaults.set(strings, forKey: Key.visitedIds)
    }

    func loadVisitedIds() -> Set<UUID> {
        let strings = defaults.stringArray(forKey: Key.visitedIds) ?? []
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    // MARK: - User Profile
    func saveUserName(_ name: String) {
        defaults.set(name, forKey: Key.userName)
    }

    func loadUserName() -> String {
        defaults.string(forKey: Key.userName) ?? "温泉旅人"
    }

    // MARK: - Custom Display Title
    func saveCustomDisplayTitle(_ title: String) {
        defaults.set(title, forKey: Key.customDisplayTitle)
    }

    func loadCustomDisplayTitle() -> String? {
        defaults.string(forKey: Key.customDisplayTitle)
    }

    // MARK: - Badges
    func saveUnlockedBadgeIds(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: Key.userBadges)
    }

    func loadUnlockedBadgeIds() -> Set<String> {
        let arr = defaults.stringArray(forKey: Key.userBadges) ?? []
        return Set(arr)
    }
}
