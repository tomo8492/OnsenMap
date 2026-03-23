import Foundation
import CoreLocation
import Combine

// MARK: - Loading State

enum DataLoadingState: Equatable {
    case idle
    case loading(progress: Int, total: Int)
    case loaded(count: Int)
    case failed(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var progressFraction: Double {
        if case .loading(let p, let t) = self, t > 0 {
            return Double(p) / Double(t)
        }
        return 0
    }

    var statusText: String {
        switch self {
        case .idle:
            return "データ未読み込み"
        case .loading(let progress, let total):
            let regionName = JapanRegion.allRegions[safe: progress - 1]?.name ?? ""
            return "読み込み中... \(regionName) (\(progress)/\(total))"
        case .loaded(let count):
            return "\(count.formatted())か所の温泉を読み込みました"
        case .failed(let msg):
            return "エラー: \(msg)"
        }
    }
}

// MARK: - Onsen Data Repository

/// 温泉データの統合管理リポジトリ
/// - サンプルデータ（オフライン用）
/// - OpenStreetMap / Overpass API（全国網羅）
/// - ユーザーカスタム温泉
@MainActor
final class OnsenDataRepository: ObservableObject {

    static let shared = OnsenDataRepository()

    @Published private(set) var loadingState: DataLoadingState = .idle
    @Published private(set) var osmOnsens: [Onsen] = []
    @Published private(set) var customOnsens: [Onsen] = []

    private let persistence = PersistenceService.shared
    private let cacheKey     = "onsenmap.osmCache"
    private let cacheVersionKey = "onsenmap.osmCacheVersion"
    private let currentCacheVersion = 2  // バージョンアップでキャッシュ再取得

    /// サンプルデータ + OSM データ + カスタムデータの合計
    var allOnsens: [Onsen] {
        let base = osmOnsens.isEmpty ? SampleData.onsens : osmOnsens
        return (base + customOnsens).uniqueByCoordinate()
    }

    private init() {
        customOnsens = persistence.loadCustomOnsens()
        loadCachedOSMData()
    }

    // MARK: - Full Japan Fetch

    /// 日本全国の温泉データを Overpass API から取得する
    func fetchAllJapan() async {
        guard !loadingState.isLoading else { return }

        loadingState = .loading(progress: 0, total: JapanRegion.allRegions.count)

        do {
            let fetched = try await OverpassAPIService.shared.fetchAllJapanOnsens { [weak self] progress, total in
                Task { @MainActor [weak self] in
                    self?.loadingState = .loading(progress: progress, total: total)
                }
            }

            osmOnsens = fetched
            loadingState = .loaded(count: fetched.count)
            cacheOSMData(fetched)
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Nearby Fetch

    /// 現在地周辺の温泉をリアルタイム取得する
    func fetchNearby(
        center: CLLocationCoordinate2D,
        radiusKm: Double = 10
    ) async throws -> [Onsen] {
        return try await OverpassAPIService.shared.fetchNearby(center: center, radiusKm: radiusKm)
    }

    // MARK: - Custom Onsens

    func addCustomOnsen(_ onsen: Onsen) {
        customOnsens.append(onsen)
        saveCustomOnsens()
    }

    func deleteCustomOnsen(_ onsen: Onsen) {
        customOnsens.removeAll { $0.id == onsen.id }
        saveCustomOnsens()
    }

    private func saveCustomOnsens() {
        persistence.saveCustomOnsens(customOnsens)
    }

    // MARK: - Cache

    private func cacheOSMData(_ onsens: [Onsen]) {
        guard let data = try? JSONEncoder().encode(onsens) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(currentCacheVersion, forKey: cacheVersionKey)
    }

    private func loadCachedOSMData() {
        let cachedVersion = UserDefaults.standard.integer(forKey: cacheVersionKey)
        guard cachedVersion >= currentCacheVersion,
              let data   = UserDefaults.standard.data(forKey: cacheKey),
              let onsens = try? JSONDecoder().decode([Onsen].self, from: data),
              !onsens.isEmpty else {
            // キャッシュなし or 古いバージョン → サンプルデータで初期化
            loadingState = .idle
            return
        }
        osmOnsens    = onsens
        loadingState = .loaded(count: onsens.count)
    }

    /// キャッシュをクリアして再取得を促す
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheVersionKey)
        osmOnsens = []
        loadingState = .idle
    }

    /// 秘湯のみを返す
    var secretOnsens: [Onsen] {
        allOnsens.filter { $0.facilities.contains("秘湯") }
    }

    /// 特定の泉質でフィルター
    func onsens(withSpringQuality quality: String) -> [Onsen] {
        allOnsens.filter { ($0.springQuality ?? "").contains(quality) }
    }
}

// MARK: - Array extension: unique by coordinate

private extension Array where Element == Onsen {
    func uniqueByCoordinate() -> [Onsen] {
        var seen: [(Double, Double)] = []
        return filter { onsen in
            let isDup = seen.contains {
                abs($0.0 - onsen.latitude)  < 0.0005 &&
                abs($0.1 - onsen.longitude) < 0.0005
            }
            if isDup { return false }
            seen.append((onsen.latitude, onsen.longitude))
            return true
        }
    }
}

// MARK: - Safe Array subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
