import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit

// MARK: - OnsenViewModel
@MainActor
final class OnsenViewModel: ObservableObject {

    // MARK: - Published State
    @Published var allOnsens: [Onsen] = []
    @Published var visits: [Visit] = []
    @Published var visitedIds: Set<UUID> = []
    @Published var unlockedBadgeIds: Set<String> = []
    @Published var userName: String = "温泉旅人"
    @Published var searchText: String = ""
    @Published var selectedPrefecture: String? = nil

    private let persistence = PersistenceService.shared

    // MARK: - Init
    init() {
        loadData()
        checkBadges()
    }

    // MARK: - Computed Properties

    /// フィルタリング済みの温泉一覧
    var filteredOnsens: [Onsen] {
        var result = allOnsens
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.contains(searchText) ||
                $0.address.contains(searchText) ||
                $0.prefecture.contains(searchText) ||
                ($0.springQuality ?? "").contains(searchText)
            }
        }
        if let prefecture = selectedPrefecture {
            result = result.filter { $0.prefecture == prefecture }
        }
        return result
    }

    /// 訪問済み温泉
    var visitedOnsens: [Onsen] {
        allOnsens.filter { visitedIds.contains($0.id) }
    }

    /// 未訪問温泉
    var unvisitedOnsens: [Onsen] {
        allOnsens.filter { !visitedIds.contains($0.id) }
    }

    /// ユニークな訪問数（同じ温泉への複数訪問は1回としてカウント）
    var uniqueVisitCount: Int { visitedIds.count }

    /// 総訪問回数（同じ温泉への複数回訪問も含む）
    var totalVisitCount: Int { visits.count }

    /// 都道府県一覧
    var prefectures: [String] {
        Array(Set(allOnsens.map { $0.prefecture })).sorted()
    }

    /// 制覇した都道府県
    var visitedPrefectures: Set<String> {
        Set(visitedOnsens.map { $0.prefecture })
    }

    /// 現在の称号
    var currentTitle: Title {
        Title.current(for: uniqueVisitCount)
    }

    /// 次の称号
    var nextTitle: Title? {
        Title.next(after: uniqueVisitCount)
    }

    /// 次の称号まであと何か所
    var visitsUntilNextTitle: Int? {
        guard let next = nextTitle else { return nil }
        return next.requiredVisits - uniqueVisitCount
    }

    /// 称号進捗 (0.0〜1.0)
    var titleProgress: Double {
        let current = currentTitle
        guard let next = nextTitle else { return 1.0 }
        let range = next.requiredVisits - current.requiredVisits
        let done  = uniqueVisitCount - current.requiredVisits
        return Double(done) / Double(range)
    }

    /// バッジ一覧（解除状態つき）
    var badges: [Badge] {
        Badge.all.map { badge in
            var b = badge
            b.isUnlocked = unlockedBadgeIds.contains(badge.id)
            return b
        }
    }

    // MARK: - Onsen Operations

    /// 温泉が訪問済みかチェック
    func isVisited(_ onsen: Onsen) -> Bool {
        visitedIds.contains(onsen.id)
    }

    /// 日記エントリーを追加（訪問済みにする）
    func addVisit(_ visit: Visit) {
        visits.insert(visit, at: 0)
        visitedIds.insert(visit.onsenId)
        saveData()
        checkBadges()
    }

    /// 日記エントリーを削除
    func deleteVisit(_ visit: Visit) {
        visits.removeAll { $0.id == visit.id }
        // まだ他の訪問が残っているかチェック
        if !visits.contains(where: { $0.onsenId == visit.onsenId }) {
            visitedIds.remove(visit.onsenId)
        }
        saveData()
    }

    /// 日記エントリーを更新
    func updateVisit(_ visit: Visit) {
        if let index = visits.firstIndex(where: { $0.id == visit.id }) {
            visits[index] = visit
            saveData()
        }
    }

    /// 特定の温泉の訪問履歴
    func visitsFor(_ onsen: Onsen) -> [Visit] {
        visits.filter { $0.onsenId == onsen.id }.sorted { $0.date > $1.date }
    }

    /// 温泉名から訪問履歴を検索
    func visits(for onsenId: UUID) -> [Visit] {
        visits.filter { $0.onsenId == onsenId }
    }

    // MARK: - User Profile
    func updateUserName(_ name: String) {
        userName = name
        persistence.saveUserName(name)
    }

    // MARK: - Badge Check
    func checkBadges() {
        var newBadges = unlockedBadgeIds

        // 初入浴
        if !visits.isEmpty { newBadges.insert("first_visit") }

        // 写真付き日記
        if visits.contains(where: { !$0.photoFileNames.isEmpty }) {
            newBadges.insert("photo_debut")
        }

        // 5つ星評価
        if visits.contains(where: { $0.rating == 5 }) {
            newBadges.insert("five_stars")
        }

        // 雪の日入浴
        if visits.contains(where: { $0.weather == .snowy }) {
            newBadges.insert("snow_bath")
        }

        // ひとり旅
        if visits.contains(where: { $0.companions.isEmpty }) {
            newBadges.insert("solo_trip")
        }

        // グループ旅行
        if visits.contains(where: { $0.companions.count >= 2 }) {
            newBadges.insert("group_trip")
        }

        // 3県制覇
        if visitedPrefectures.count >= 3  { newBadges.insert("prefecture_3") }
        if visitedPrefectures.count >= 10 { newBadges.insert("prefecture_10") }

        // 100か所
        if uniqueVisitCount >= 100 { newBadges.insert("onsen_100") }

        // レビューマスター（50件のノート）
        let notedVisits = visits.filter { !$0.notes.isEmpty }
        if notedVisits.count >= 50 { newBadges.insert("review_master") }

        // 週イチ常連（1週間以内に3回）
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let recentVisits = visits.filter { $0.date >= oneWeekAgo }
        if recentVisits.count >= 3 { newBadges.insert("weekly_visitor") }

        if newBadges != unlockedBadgeIds {
            unlockedBadgeIds = newBadges
            persistence.saveUnlockedBadgeIds(newBadges)
        }
    }

    // MARK: - Share Text
    func shareText() -> String {
        """
        🌊 \(userName) の温泉記録
        📍 訪問した温泉: \(uniqueVisitCount)か所
        🏆 称号: \(currentTitle.name)
        🗾 制覇した都道府県: \(visitedPrefectures.count)都道府県

        #OnsenMap #温泉 #温泉巡り #\(currentTitle.name)
        """
    }

    // MARK: - Data Persistence
    private func loadData() {
        let customOnsens = persistence.loadCustomOnsens()
        allOnsens = SampleData.onsens + customOnsens
        visits = persistence.loadVisits()
        visitedIds = persistence.loadVisitedIds()
        unlockedBadgeIds = persistence.loadUnlockedBadgeIds()
        userName = persistence.loadUserName()
    }

    private func saveData() {
        persistence.saveVisits(visits)
        persistence.saveVisitedIds(visitedIds)
    }
}

// MARK: - LocationViewModel
final class LocationViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var nearbyOnsens: [Onsen] = []

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }

    /// MapKit を使って周辺の温泉を検索する
    func searchNearbyOnsens(center: CLLocationCoordinate2D, radius: CLLocationDistance = 10_000) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "温泉"
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius,
            longitudinalMeters: radius
        )
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems
        } catch {
            return []
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}
