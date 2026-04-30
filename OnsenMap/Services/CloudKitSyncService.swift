import Foundation
import CloudKit
import Combine

// MARK: - CloudKit Sync Service
/// ユーザーの記録（訪問・日記・バッジ・カスタム温泉・プロフィール）を
/// iCloud Private Database に同期するサービス。
///
/// 設計方針:
/// - ローカル UserDefaults を一次キャッシュ（オフラインでも即時動作）
/// - CloudKit を「真実のソース」として扱い、起動時に pull→merge
/// - 変更操作のたびに incremental push
/// - 同期は失敗してもアプリ動作は止めない（fire-and-forget）
@MainActor
final class CloudKitSyncService: ObservableObject {

    static let shared = CloudKitSyncService()

    // MARK: - Sync State
    enum SyncState: Equatable {
        case idle
        case syncing
        case synced(Date)
        case failed(String)
        case unavailable        // iCloud 未ログインなど

        var statusText: String {
            switch self {
            case .idle:                  return "未同期"
            case .syncing:               return "同期中..."
            case .synced(let date):
                let f = DateFormatter()
                f.dateStyle = .none
                f.timeStyle = .short
                return "最終同期: \(f.string(from: date))"
            case .failed(let msg):       return "同期失敗: \(msg)"
            case .unavailable:           return "iCloud未ログイン"
            }
        }
    }

    @Published private(set) var state: SyncState = .idle
    @Published private(set) var iCloudAvailable: Bool = false

    private let container = CKContainer.default()
    private var db: CKDatabase { container.privateCloudDatabase }

    // MARK: - Record Types
    private enum RT {
        static let visit         = "Visit"
        static let visitedOnsen  = "VisitedOnsen"
        static let badge         = "UnlockedBadge"
        static let customOnsen   = "CustomOnsen"
        static let profile       = "UserProfile"
    }

    private enum SyncError: LocalizedError {
        case iCloudUnavailable
        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable: return "iCloudにログインしていません"
            }
        }
    }

    private init() {}

    // MARK: - Account Status
    func refreshAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            iCloudAvailable = (status == .available)
            if !iCloudAvailable, state != .syncing {
                state = .unavailable
            }
        } catch {
            iCloudAvailable = false
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Snapshot
    struct Snapshot {
        var visits: [Visit] = []
        var visitedIds: Set<UUID> = []
        var unlockedBadges: Set<String> = []
        var customOnsens: [Onsen] = []
        var userName: String?
    }

    // MARK: - Pull (download all)
    func pullSnapshot() async throws -> Snapshot {
        guard iCloudAvailable else { throw SyncError.iCloudUnavailable }

        state = .syncing
        do {
            async let v  = fetchVisits()
            async let vi = fetchVisitedIds()
            async let bg = fetchBadges()
            async let co = fetchCustomOnsens()
            async let un = fetchUserName()

            let snap = Snapshot(
                visits:         try await v,
                visitedIds:     try await vi,
                unlockedBadges: try await bg,
                customOnsens:   try await co,
                userName:       try await un
            )
            state = .synced(Date())
            return snap
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Generic fetch all of a record type
    private func fetchAllRecords(of type: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var results: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        // 初回クエリ
        let (matchResults, nextCursor) = try await db.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)
        for (_, recordResult) in matchResults {
            if case .success(let rec) = recordResult { results.append(rec) }
        }
        cursor = nextCursor

        // ページング
        while let c = cursor {
            let (more, next) = try await db.records(continuingMatchFrom: c, resultsLimit: CKQueryOperation.maximumResults)
            for (_, recordResult) in more {
                if case .success(let rec) = recordResult { results.append(rec) }
            }
            cursor = next
        }
        return results
    }

    // MARK: - Visit fetch/parse
    private func fetchVisits() async throws -> [Visit] {
        let records = try await fetchAllRecords(of: RT.visit)
        return records.compactMap(Self.visit(from:))
    }

    private static func visit(from r: CKRecord) -> Visit? {
        guard let idStr   = r["id"] as? String,
              let id      = UUID(uuidString: idStr),
              let onsenIdStr = r["onsenId"] as? String,
              let onsenId   = UUID(uuidString: onsenIdStr),
              let onsenName = r["onsenName"] as? String,
              let date      = r["date"] as? Date,
              let rating    = r["rating"] as? Int,
              let moodRaw   = r["mood"] as? String,
              let mood      = Visit.Mood(rawValue: moodRaw) else {
            return nil
        }
        let weather: Visit.Weather? = (r["weather"] as? String).flatMap(Visit.Weather.init(rawValue:))
        return Visit(
            id: id,
            onsenId: onsenId,
            onsenName: onsenName,
            date: date,
            notes: (r["notes"] as? String) ?? "",
            rating: rating,
            mood: mood,
            companions: (r["companions"] as? [String]) ?? [],
            weather: weather,
            soakDurationMinutes: r["soakDurationMinutes"] as? Int,
            photoFileNames: (r["photoFileNames"] as? [String]) ?? []
        )
    }

    private static func record(from visit: Visit) -> CKRecord {
        let recID = CKRecord.ID(recordName: visit.id.uuidString)
        let r = CKRecord(recordType: RT.visit, recordID: recID)
        r["id"]                   = visit.id.uuidString
        r["onsenId"]              = visit.onsenId.uuidString
        r["onsenName"]            = visit.onsenName
        r["date"]                 = visit.date
        r["notes"]                = visit.notes
        r["rating"]               = visit.rating
        r["mood"]                 = visit.mood.rawValue
        r["companions"]           = visit.companions
        r["weather"]              = visit.weather?.rawValue
        r["soakDurationMinutes"]  = visit.soakDurationMinutes
        r["photoFileNames"]       = visit.photoFileNames
        return r
    }

    // MARK: - VisitedOnsen fetch/parse
    private func fetchVisitedIds() async throws -> Set<UUID> {
        let records = try await fetchAllRecords(of: RT.visitedOnsen)
        return Set(records.compactMap { rec -> UUID? in
            guard let s = rec["onsenId"] as? String else { return nil }
            return UUID(uuidString: s)
        })
    }

    // MARK: - Badge fetch
    private func fetchBadges() async throws -> Set<String> {
        let records = try await fetchAllRecords(of: RT.badge)
        return Set(records.compactMap { $0["badgeId"] as? String })
    }

    // MARK: - CustomOnsen fetch/parse
    private func fetchCustomOnsens() async throws -> [Onsen] {
        let records = try await fetchAllRecords(of: RT.customOnsen)
        return records.compactMap(Self.onsen(from:))
    }

    private static func onsen(from r: CKRecord) -> Onsen? {
        guard let idStr = r["id"] as? String,
              let id    = UUID(uuidString: idStr),
              let name  = r["name"] as? String,
              let lat   = r["latitude"] as? Double,
              let lon   = r["longitude"] as? Double,
              let pref  = r["prefecture"] as? String,
              let typeRaw = r["onsenType"] as? String,
              let type    = Onsen.OnsenType(rawValue: typeRaw) else {
            return nil
        }
        return Onsen(
            id: id,
            name: name,
            nameReading: (r["nameReading"] as? String) ?? "",
            address: (r["address"] as? String) ?? "",
            prefecture: pref,
            latitude: lat,
            longitude: lon,
            description: (r["description"] as? String) ?? "",
            onsenType: type,
            springQuality: r["springQuality"] as? String,
            facilities: (r["facilities"] as? [String]) ?? [],
            phoneNumber: r["phoneNumber"] as? String,
            website: r["website"] as? String,
            openingHours: r["openingHours"] as? String,
            regularHoliday: r["regularHoliday"] as? String,
            entryFee: r["entryFee"] as? String,
            hasParking: (r["hasParking"] as? Int) == 1,
            imageNames: (r["imageNames"] as? [String]) ?? []
        )
    }

    private static func record(from onsen: Onsen) -> CKRecord {
        let recID = CKRecord.ID(recordName: onsen.id.uuidString)
        let r = CKRecord(recordType: RT.customOnsen, recordID: recID)
        r["id"]              = onsen.id.uuidString
        r["name"]            = onsen.name
        r["nameReading"]     = onsen.nameReading
        r["address"]         = onsen.address
        r["prefecture"]      = onsen.prefecture
        r["latitude"]        = onsen.latitude
        r["longitude"]       = onsen.longitude
        r["description"]     = onsen.description
        r["onsenType"]       = onsen.onsenType.rawValue
        r["springQuality"]   = onsen.springQuality
        r["facilities"]      = onsen.facilities
        r["phoneNumber"]     = onsen.phoneNumber
        r["website"]         = onsen.website
        r["openingHours"]    = onsen.openingHours
        r["regularHoliday"]  = onsen.regularHoliday
        r["entryFee"]        = onsen.entryFee
        r["hasParking"]      = onsen.hasParking ? 1 : 0
        r["imageNames"]      = onsen.imageNames
        return r
    }

    // MARK: - UserProfile fetch
    private func fetchUserName() async throws -> String? {
        let recID = CKRecord.ID(recordName: "userProfile")
        do {
            let record = try await db.record(for: recID)
            return record["userName"] as? String
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    // MARK: - Push (incremental upserts)

    func upsert(visit: Visit) async {
        guard iCloudAvailable else { return }
        let record = Self.record(from: visit)
        do {
            _ = try await saveOverwriting(record)
        } catch {
            print("⚠️ CloudKit upsert visit failed: \(error)")
        }
    }

    func delete(visitId: UUID) async {
        guard iCloudAvailable else { return }
        let recID = CKRecord.ID(recordName: visitId.uuidString)
        do {
            _ = try await db.deleteRecord(withID: recID)
        } catch let error as CKError where error.code == .unknownItem {
            // 既に削除済み
        } catch {
            print("⚠️ CloudKit delete visit failed: \(error)")
        }
    }

    func upsert(visitedOnsenId id: UUID) async {
        guard iCloudAvailable else { return }
        let recID = CKRecord.ID(recordName: "visited_\(id.uuidString)")
        let r = CKRecord(recordType: RT.visitedOnsen, recordID: recID)
        r["onsenId"] = id.uuidString
        do {
            _ = try await saveOverwriting(r)
        } catch {
            print("⚠️ CloudKit upsert visitedId failed: \(error)")
        }
    }

    func delete(visitedOnsenId id: UUID) async {
        guard iCloudAvailable else { return }
        let recID = CKRecord.ID(recordName: "visited_\(id.uuidString)")
        do {
            _ = try await db.deleteRecord(withID: recID)
        } catch let error as CKError where error.code == .unknownItem {
            // 既に削除済み
        } catch {
            print("⚠️ CloudKit delete visitedId failed: \(error)")
        }
    }

    func upsert(badgeId: String) async {
        guard iCloudAvailable else { return }
        let recID = CKRecord.ID(recordName: "badge_\(badgeId)")
        let r = CKRecord(recordType: RT.badge, recordID: recID)
        r["badgeId"] = badgeId
        do {
            _ = try await saveOverwriting(r)
        } catch {
            print("⚠️ CloudKit upsert badge failed: \(error)")
        }
    }

    func upsert(customOnsen: Onsen) async {
        guard iCloudAvailable else { return }
        let record = Self.record(from: customOnsen)
        do {
            _ = try await saveOverwriting(record)
        } catch {
            print("⚠️ CloudKit upsert customOnsen failed: \(error)")
        }
    }

    func delete(customOnsenId id: UUID) async {
        guard iCloudAvailable else { return }
        let recID = CKRecord.ID(recordName: id.uuidString)
        do {
            _ = try await db.deleteRecord(withID: recID)
        } catch let error as CKError where error.code == .unknownItem {
            // 既に削除済み
        } catch {
            print("⚠️ CloudKit delete customOnsen failed: \(error)")
        }
    }

    func upsert(userName: String) async {
        guard iCloudAvailable else { return }
        let recID = CKRecord.ID(recordName: "userProfile")
        let r = CKRecord(recordType: RT.profile, recordID: recID)
        r["userName"] = userName
        do {
            _ = try await saveOverwriting(r)
        } catch {
            print("⚠️ CloudKit upsert userName failed: \(error)")
        }
    }

    // MARK: - Save with overwrite-on-conflict
    /// `CKModifyRecordsOperation` の savePolicy を `.changedKeys` に指定し、
    /// 既存レコードがあっても上書き保存する。
    @discardableResult
    private func saveOverwriting(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            op.savePolicy = .changedKeys
            op.qualityOfService = .userInitiated
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: record)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            db.add(op)
        }
    }

    // MARK: - Manual full sync
    /// プロフィール画面などから手動で全同期（pull のみ）
    func performManualSync() async -> Snapshot? {
        await refreshAccountStatus()
        guard iCloudAvailable else { return nil }
        do {
            return try await pullSnapshot()
        } catch {
            return nil
        }
    }
}
