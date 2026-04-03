import SwiftUI
import GameKit

// MARK: - Ranking View（世界ランキング）
struct RankingView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @EnvironmentObject var gc: GameCenterService
    @State private var selectedScope: RankScope = .global
    @State private var showingGCDashboard = false

    enum RankScope: String, CaseIterable {
        case global  = "世界"
        case friends = "フレンド"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ─── 自分のランク表示 ───
                MyRankBanner()

                // ─── スコープ切り替え ───
                Picker("スコープ", selection: $selectedScope) {
                    ForEach(RankScope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedScope) { _, scope in
                    Task {
                        if scope == .global { await gc.loadGlobalRanking() }
                        else                { await gc.loadFriendsRanking() }
                    }
                }

                // ─── ランキングリスト ───
                if !gc.isAuthenticated {
                    GameCenterSignInPrompt()
                } else if gc.isLoadingRanking {
                    Spacer()
                    ProgressView("ランキングを読み込み中...")
                    Spacer()
                } else {
                    let entries = selectedScope == .global ? gc.globalEntries : gc.friendEntries
                    if entries.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "trophy")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("まだランキングデータがありません")
                                .foregroundStyle(.secondary)
                            Text("温泉に行ってスコアを登録しよう！")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    } else {
                        List {
                            // 上位3名（ポジウム表示）
                            if entries.count >= 3 {
                                Section {
                                    PodiumView(entries: Array(entries.prefix(3)))
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)
                                }
                            }

                            // 4位以降
                            Section {
                                ForEach(entries.dropFirst(min(3, entries.count))) { entry in
                                    RankRowView(entry: entry)
                                }
                            }

                            // 広告
                            Section {
                                AdBannerView(adUnitID: "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX")
                                    .listRowInsets(EdgeInsets())
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("世界ランキング")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGCDashboard = true
                    } label: {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundStyle(.orange)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            if selectedScope == .global { await gc.loadGlobalRanking() }
                            else                        { await gc.loadFriendsRanking() }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if gc.isAuthenticated {
                    await gc.loadGlobalRanking()
                }
                // 訪問数をスコアとして送信
                gc.submitScore(viewModel.uniqueVisitCount)
            }
            .fullScreenCover(isPresented: $showingGCDashboard) {
                GameCenterDashboardView()
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - My Rank Banner
struct MyRankBanner: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @EnvironmentObject var gc: GameCenterService

    var body: some View {
        HStack(spacing: 16) {
            // アバター
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [viewModel.currentTitle.color.opacity(0.7),
                                     viewModel.currentTitle.color.opacity(0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                if let photo = gc.playerPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                } else {
                    Image(systemName: viewModel.currentTitle.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.customDisplayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text("訪問数: \(viewModel.uniqueVisitCount)か所")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 自分のランク
            VStack(spacing: 2) {
                if let rank = gc.myRank {
                    Text("\(rank)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("位")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("圏外")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Podium View（1〜3位）
struct PodiumView: View {
    let entries: [RankEntry]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if entries.count >= 2 { PodiumCell(entry: entries[1], height: 80) }   // 2位
            if entries.count >= 1 { PodiumCell(entry: entries[0], height: 110) }  // 1位
            if entries.count >= 3 { PodiumCell(entry: entries[2], height: 60) }   // 3位
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

struct PodiumCell: View {
    let entry: RankEntry
    let height: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            Text(entry.medalIcon)
                .font(.system(size: entry.rank == 1 ? 36 : 28))
            Text(entry.playerName)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: 80)
            Text("\(entry.score)か所")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(entry.titleName)
                .font(.system(size: 9))
                .foregroundStyle(Title.current(for: entry.score).color)
                .lineLimit(1)

            // 台
            Rectangle()
                .fill(entry.rank == 1
                      ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.4)
                      : Color(.systemGray5))
                .frame(width: 80, height: height)
                .cornerRadius(4, corners: [.topLeft, .topRight])
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Rank Row View（4位以降）
struct RankRowView: View {
    let entry: RankEntry

    var body: some View {
        HStack(spacing: 12) {
            // 順位
            Text(entry.medalIcon)
                .font(.subheadline)
                .fontWeight(.bold)
                .frame(width: 32)

            // プレイヤー情報
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.playerName)
                    .font(.subheadline)
                    .fontWeight(entry.isLocalPlayer ? .bold : .regular)
                Text(entry.titleName)
                    .font(.caption2)
                    .foregroundStyle(Title.current(for: entry.score).color)
            }

            Spacer()

            // スコア
            Text("\(entry.score)か所")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(entry.isLocalPlayer ? .orange : .primary)
        }
        .padding(.vertical, 2)
        .listRowBackground(entry.isLocalPlayer ? Color.orange.opacity(0.08) : Color.clear)
    }
}

// MARK: - Game Center Sign In Prompt
struct GameCenterSignInPrompt: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange.opacity(0.7))
            Text("Game Center でランキングに参加しよう")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("設定 → Game Center からサインインすると\n世界中の温泉ハンターと競えます！")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: "App-Prefs:GAME_CENTER") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Game Center を開く", systemImage: "arrow.up.right.square")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            Spacer()
        }
    }
}

// MARK: - Game Center Dashboard Wrapper
struct GameCenterDashboardView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(state: .leaderboards)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func gameCenterViewControllerDidFinish(_ gc: GKGameCenterViewController) { dismiss() }
    }
}

// MARK: - Corner Radius helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
