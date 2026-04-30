import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit

// MARK: - OnsenViewModel
@MainActor
final class OnsenViewModel: ObservableObject {

    // MARK: - Published State
    @Published var visits: [Visit] = []
    @Published var visitedIds: Set<UUID> = []
    @Published var unlockedBadgeIds: Set<String> = []
    @Published var userName: String = "温泉旅人"
    @Published var searchText: String = ""
    @Published var selectedPrefecture: String? = nil
    @Published var selectedTypes: Set<Onsen.OnsenType> = []
    @Published var showSecretOnly: Bool = false

    // DataRepository を通じてデータを取得
    let repository = OnsenDataRepository.shared
    private let persistence = PersistenceService.shared
    let cloudSync = CloudKitSyncService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        loadUserData()
        checkBadges()

        // Repository の変更を購読して自動更新
        repository.$osmOnsens
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        repository.$customOnsens
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // CloudKit 同期状態の変更を View に伝播
        cloudSync.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // 起動時に iCloud から pull → ローカルとマージ
        Task { await self.initialCloudSync() }
    }

    // MARK: - Initial Cloud Sync
    /// 起動時に iCloud から最新データを取得し、ローカルとユニオンマージする。
    /// オフライン or iCloud未ログイン時は何もせずローカルのみで動作。
    func initialCloudSync() async {
        await cloudSync.refreshAccountStatus()
        guard cloudSync.iCloudAvailable else { return }

        guard let snap = try? await cloudSync.pullSnapshot() else { return }

        // Visits: id ベースでユニオン（同一 id はクラウド優先）
        var mergedVisitsById = Dictionary(uniqueKeysWithValues: visits.map { ($0.id, $0) })
        for v in snap.visits { mergedVisitsById[v.id] = v }
        visits = mergedVisitsById.values.sorted { $0.date > $1.date }

        // VisitedIds: ユニオン
        visitedIds.formUnion(snap.visitedIds)

        // Badges: ユニオン
        unlockedBadgeIds.formUnion(snap.unlockedBadges)

        // UserName: クラウドにあればそちらを優先
        if let cloudName = snap.userName, !cloudName.isEmpty {
            userName = cloudName
            persistence.saveUserName(cloudName)
        }

        // Custom onsens: Repository 側でマージ
        repository.mergeCustomOnsensFromCloud(snap.customOnsens)

        saveUserData()
        checkBadges()

        // ローカルにあってクラウドに無い分を push（初回登録ユーザー対応）
        await pushLocalOnlyChangesAfterMerge(cloudSnapshot: snap)
    }

    /// マージ後、ローカルだけにあった記録をクラウドへアップロードする
    private func pushLocalOnlyChangesAfterMerge(cloudSnapshot snap: CloudKitSyncService.Snapshot) async {
        let cloudVisitIds = Set(snap.visits.map { $0.id })
        for v in visits where !cloudVisitIds.contains(v.id) {
            await cloudSync.upsert(visit: v)
        }
        for id in visitedIds.subtracting(snap.visitedIds) {
            await cloudSync.upsert(visitedOnsenId: id)
        }
        for badgeId in unlockedBadgeIds.subtracting(snap.unlockedBadges) {
            await cloudSync.upsert(badgeId: badgeId)
        }
        if snap.userName == nil || snap.userName?.isEmpty == true {
            await cloudSync.upsert(userName: userName)
        }
    }

    // MARK: - Computed Properties

    /// 全温泉（OSM + サンプル + カスタム）
    var allOnsens: [Onsen] { repository.allOnsens }

    /// ローディング状態
    var loadingState: DataLoadingState { repository.loadingState }

    /// フィルタリング済みの温泉一覧
    var filteredOnsens: [Onsen] {
        var result = allOnsens

        // 秘湯フィルター
        if showSecretOnly {
            result = result.filter { $0.facilities.contains("秘湯") }
        }

        // テキスト検索
        if !searchText.isEmpty {
            let q = searchText
            result = result.filter {
                $0.name.contains(q) ||
                $0.nameReading.contains(q) ||
                $0.address.contains(q) ||
                $0.prefecture.contains(q) ||
                ($0.springQuality ?? "").contains(q) ||
                $0.facilities.joined().contains(q)
            }
        }

        // 都道府県フィルター
        if let pref = selectedPrefecture {
            result = result.filter { $0.prefecture == pref }
        }

        // 種別フィルター
        if !selectedTypes.isEmpty {
            result = result.filter { selectedTypes.contains($0.onsenType) }
        }

        return result
    }

    /// 訪問済み温泉
    var visitedOnsens: [Onsen] {
        allOnsens.filter { visitedIds.contains($0.id) }
    }

    /// ユニーク訪問数
    var uniqueVisitCount: Int { visitedIds.count }

    /// 総入浴回数
    var totalVisitCount: Int { visits.count }

    /// 都道府県一覧（データに存在するものだけ）
    var prefectures: [String] {
        Array(Set(allOnsens.map { $0.prefecture })).sorted()
    }

    /// 訪問済み都道府県
    var visitedPrefectures: Set<String> {
        Set(visitedOnsens.map { $0.prefecture })
    }

    /// 秘湯一覧
    var secretOnsens: [Onsen] { repository.secretOnsens }

    /// 現在の称号
    var currentTitle: Title  { Title.current(for: uniqueVisitCount) }

    /// 次の称号
    var nextTitle: Title?     { Title.next(after: uniqueVisitCount) }

    /// 次の称号まであと何か所
    var visitsUntilNextTitle: Int? {
        nextTitle.map { $0.requiredVisits - uniqueVisitCount }
    }

    /// 称号進捗 0.0〜1.0
    var titleProgress: Double {
        let cur = currentTitle
        guard let nxt = nextTitle else { return 1.0 }
        let range = nxt.requiredVisits - cur.requiredVisits
        let done  = uniqueVisitCount   - cur.requiredVisits
        return Double(done) / Double(range)
    }

    /// バッジ一覧（解除状態付き）
    var badges: [Badge] {
        Badge.all.map { b in
            var copy = b
            copy.isUnlocked = unlockedBadgeIds.contains(b.id)
            return copy
        }
    }

    // MARK: - Data Fetching

    /// 全国データを取得（初回 or 手動更新時）
    func fetchFullDatabase() async {
        await repository.fetchAllJapan()
    }

    /// キャッシュをクリアして再取得
    func refreshDatabase() async {
        repository.clearCache()
        await repository.fetchAllJapan()
    }

    // MARK: - Onsen Operations

    func isVisited(_ onsen: Onsen) -> Bool {
        visitedIds.contains(onsen.id)
    }

    func addVisit(_ visit: Visit) {
        visits.insert(visit, at: 0)
        let isFirstVisitToOnsen = !visitedIds.contains(visit.onsenId)
        visitedIds.insert(visit.onsenId)
        saveUserData()
        checkBadges()

        Task {
            await cloudSync.upsert(visit: visit)
            if isFirstVisitToOnsen {
                await cloudSync.upsert(visitedOnsenId: visit.onsenId)
            }
        }
    }

    func deleteVisit(_ visit: Visit) {
        visits.removeAll { $0.id == visit.id }
        let stillVisited = visits.contains(where: { $0.onsenId == visit.onsenId })
        if !stillVisited {
            visitedIds.remove(visit.onsenId)
        }
        saveUserData()

        Task {
            await cloudSync.delete(visitId: visit.id)
            if !stillVisited {
                await cloudSync.delete(visitedOnsenId: visit.onsenId)
            }
        }
    }

    func updateVisit(_ visit: Visit) {
        if let i = visits.firstIndex(where: { $0.id == visit.id }) {
            visits[i] = visit
            saveUserData()
            Task { await cloudSync.upsert(visit: visit) }
        }
    }

    func visitsFor(_ onsen: Onsen) -> [Visit] {
        visits.filter { $0.onsenId == onsen.id }.sorted { $0.date > $1.date }
    }

    // MARK: - Custom Onsens

    func addCustomOnsen(_ onsen: Onsen) {
        repository.addCustomOnsen(onsen)
    }

    // MARK: - User Profile

    func updateUserName(_ name: String) {
        userName = name
        persistence.saveUserName(name)
        Task { await cloudSync.upsert(userName: name) }
    }

    // MARK: - Filters

    func clearFilters() {
        searchText = ""
        selectedPrefecture = nil
        selectedTypes = []
        showSecretOnly = false
    }

    var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedPrefecture != nil ||
        !selectedTypes.isEmpty || showSecretOnly
    }

    // MARK: - Badge Check
    func checkBadges() {
        var nb = unlockedBadgeIds

        if !visits.isEmpty               { nb.insert("first_visit") }
        if visits.contains(where: { !$0.photoFileNames.isEmpty }) { nb.insert("photo_debut") }
        if visits.contains(where: { $0.rating == 5 })             { nb.insert("five_stars") }
        if visits.contains(where: { $0.weather == .snowy })       { nb.insert("snow_bath") }
        if visits.contains(where: { $0.companions.isEmpty })      { nb.insert("solo_trip") }
        if visits.contains(where: { $0.companions.count >= 2 })   { nb.insert("group_trip") }
        if visitedPrefectures.count >= 3   { nb.insert("prefecture_3") }
        if visitedPrefectures.count >= 10  { nb.insert("prefecture_10") }
        if uniqueVisitCount >= 100         { nb.insert("onsen_100") }

        let notedVisits = visits.filter { !$0.notes.isEmpty }
        if notedVisits.count >= 50 { nb.insert("review_master") }

        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        if visits.filter({ $0.date >= oneWeekAgo }).count >= 3 { nb.insert("weekly_visitor") }

        // 夜の湯（20時以降に入浴）
        let cal = Calendar.current
        if visits.contains(where: { cal.component(.hour, from: $0.date) >= 20 }) {
            nb.insert("night_bath")
        }

        // 秘湯バッジ（秘湯を1か所訪問）
        let visitedSecretIds = Set(visitedOnsens.filter { $0.facilities.contains("秘湯") }.map { $0.id })
        if !visitedSecretIds.isEmpty { nb.insert("secret_onsen") }

        if nb != unlockedBadgeIds {
            let newlyUnlocked = nb.subtracting(unlockedBadgeIds)
            unlockedBadgeIds = nb
            persistence.saveUnlockedBadgeIds(nb)

            Task {
                for id in newlyUnlocked {
                    await cloudSync.upsert(badgeId: id)
                }
            }
        }
    }

    // MARK: - Share
    func shareText() -> String {
        """
        🌊 \(userName) の温泉記録
        📍 訪問した温泉: \(uniqueVisitCount)か所（秘湯含む）
        🏆 称号: \(currentTitle.name)
        🗾 制覇した都道府県: \(visitedPrefectures.count)都道府県

        #OnsenMap #温泉 #温泉巡り #\(currentTitle.name)
        """
    }

    // MARK: - Persistence (user data only)
    private func loadUserData() {
        visits           = persistence.loadVisits()
        visitedIds       = persistence.loadVisitedIds()
        unlockedBadgeIds = persistence.loadUnlockedBadgeIds()
        userName         = persistence.loadUserName()
    }

    private func saveUserData() {
        persistence.saveVisits(visits)
        persistence.saveVisitedIds(visitedIds)
    }
}

// MARK: - LocationViewModel
final class LocationViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdating() { locationManager.startUpdatingLocation() }
    func stopUpdating()  { locationManager.stopUpdatingLocation() }

    /// MapKit で周辺の温泉を検索
    func searchNearbyOnsens(center: CLLocationCoordinate2D, radius: CLLocationDistance = 10_000) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "温泉"
        request.region = MKCoordinateRegion(center: center,
                                            latitudinalMeters: radius,
                                            longitudinalMeters: radius)
        do {
            return try await MKLocalSearch(request: request).start().mapItems
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
