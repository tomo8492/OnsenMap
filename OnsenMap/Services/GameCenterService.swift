import Foundation
import GameKit
import SwiftUI

// MARK: - Game Center Service
/// Apple Game Center を使った世界ランキング機能
/// App Store Connect でリーダーボードを作成後に leaderboardID を差し替えてください
@MainActor
final class GameCenterService: NSObject, ObservableObject {

    static let shared = GameCenterService()
    private override init() { super.init() }

    // App Store Connect で作成するリーダーボード ID
    static let leaderboardID = "com.yourcompany.onsenmap.uniquevisits"

    // MARK: - Published State
    @Published var isAuthenticated = false
    @Published var playerName: String = ""
    @Published var playerPhoto: UIImage? = nil
    @Published var globalEntries: [RankEntry] = []
    @Published var friendEntries: [RankEntry] = []
    @Published var myRank: Int? = nil
    @Published var isLoadingRanking = false
    @Published var authError: String? = nil

    // MARK: - Authentication（起動時に呼ぶ）
    func authenticateOnLaunch() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] gcViewController, error in
            guard let self else { return }

            if let vc = gcViewController {
                // Game Center ログイン画面を自動的に最前面に表示
                DispatchQueue.main.async {
                    UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .first { $0.isKeyWindow }?
                        .rootViewController?
                        .present(vc, animated: true)
                }
            } else if GKLocalPlayer.local.isAuthenticated {
                self.isAuthenticated = true
                self.playerName = GKLocalPlayer.local.displayName
                Task {
                    if let photo = try? await GKLocalPlayer.local.loadPhoto(for: .normal) {
                        self.playerPhoto = photo
                    }
                    await self.loadGlobalRanking()
                }
            } else {
                self.isAuthenticated = false
                self.authError = error?.localizedDescription
            }
        }
    }

    // MARK: - Authentication（UIから手動起動・後方互換）
    func authenticate(presenting viewController: UIViewController) {
        GKLocalPlayer.local.authenticateHandler = { [weak self] gcViewController, error in
            guard let self else { return }
            if let vc = gcViewController {
                viewController.present(vc, animated: true)
            } else if GKLocalPlayer.local.isAuthenticated {
                self.isAuthenticated = true
                self.playerName = GKLocalPlayer.local.displayName
            } else {
                self.authError = error?.localizedDescription
            }
        }
    }

    // MARK: - Submit Score
    func submitScore(_ visitCount: Int) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        Task {
            try? await GKLeaderboard.submitScore(
                visitCount,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [GameCenterService.leaderboardID]
            )
        }
    }

    // MARK: - Load Global Ranking (Top 100)
    func loadGlobalRanking() async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [GameCenterService.leaderboardID])
            guard let board = boards.first else { return }

            let (myEntry, entries, _) = try await board.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: NSRange(location: 1, length: 100)
            )
            myRank = myEntry?.rank

            globalEntries = entries.map { entry in
                RankEntry(
                    rank:        entry.rank,
                    playerName:  entry.player.displayName,
                    score:       entry.score,
                    isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
                )
            }
        } catch {
            print("⚠️ Leaderboard load error: \(error)")
        }
    }

    // MARK: - Load Friends Ranking
    func loadFriendsRanking() async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [GameCenterService.leaderboardID])
            guard let board = boards.first else { return }

            let (_, entries, _) = try await board.loadEntries(
                for: .friendsOnly,
                timeScope: .allTime,
                range: NSRange(location: 1, length: 50)
            )
            friendEntries = entries.map { entry in
                RankEntry(
                    rank:        entry.rank,
                    playerName:  entry.player.displayName,
                    score:       entry.score,
                    isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
                )
            }
        } catch {
            print("⚠️ Friends leaderboard error: \(error)")
        }
    }

    // MARK: - Open Game Center UI (Native)
    func showGameCenterDashboard(from viewController: UIViewController) {
        let vc = GKGameCenterViewController(state: .leaderboards)
        vc.gameCenterDelegate = self
        viewController.present(vc, animated: true)
    }
}

// MARK: - GKGameCenterControllerDelegate
extension GameCenterService: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}

// MARK: - Rank Entry Model
struct RankEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let playerName: String
    let score: Int          // 訪問数
    let isLocalPlayer: Bool

    var titleName: String { Title.current(for: score).name }
    var medalIcon: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }
}
