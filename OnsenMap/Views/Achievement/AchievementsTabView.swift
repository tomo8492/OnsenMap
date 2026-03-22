import SwiftUI

// MARK: - Achievements Tab View（称号・バッジ）
struct AchievementsTabView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ─── 現在の称号カード ───
                    CurrentTitleCard()
                        .padding(.horizontal)

                    // ─── 称号ロードマップ ───
                    TitleRoadmapView()
                        .padding(.horizontal)

                    // ─── 広告 ───
                    AdBannerView(adUnitID: "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX")
                        .padding(.horizontal)

                    // ─── バッジコレクション ───
                    BadgeCollectionView()
                        .padding(.horizontal)

                    // ─── 統計 ───
                    StatsDetailView()
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
                .padding(.top)
            }
            .navigationTitle("称号・バッジ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("シェア", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareAchievementView()
            }
        }
    }
}

// MARK: - Current Title Card
struct CurrentTitleCard: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        let title = viewModel.currentTitle

        VStack(spacing: 16) {
            // アイコン + 称号名
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [title.color.opacity(0.3), title.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: title.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(title.color)
                }

                Text(title.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(title.color)

                Text(title.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(title.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            // 訪問数
            HStack(spacing: 24) {
                VStack {
                    Text("\(viewModel.uniqueVisitCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("訪問した温泉")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(viewModel.totalVisitCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text("総入浴回数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(viewModel.visitedPrefectures.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("都道府県")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 次の称号へのプログレスバー
            if let next = viewModel.nextTitle,
               let remaining = viewModel.visitsUntilNextTitle {
                VStack(spacing: 6) {
                    HStack {
                        Text("次の称号まで")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("あと\(remaining)か所 → \(next.name)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(next.color)
                    }
                    ProgressView(value: viewModel.titleProgress)
                        .tint(next.color)
                }
            } else {
                Text("🎉 最高称号「\(viewModel.currentTitle.name)」を達成！")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Title Roadmap View
struct TitleRoadmapView: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("称号ロードマップ")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(Title.all) { title in
                let isUnlocked = viewModel.uniqueVisitCount >= title.requiredVisits
                let isCurrent  = viewModel.currentTitle.id == title.id

                HStack(spacing: 12) {
                    // アイコン
                    ZStack {
                        Circle()
                            .fill(isUnlocked ? title.color : Color(.systemGray5))
                            .frame(width: 40, height: 40)
                        Image(systemName: title.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(isUnlocked ? .white : Color(.systemGray3))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(title.name)
                                .font(.subheadline)
                                .fontWeight(isCurrent ? .bold : .regular)
                                .foregroundStyle(isUnlocked ? .primary : .secondary)
                            if isCurrent {
                                Text("現在")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(title.color)
                                    .cornerRadius(10)
                            }
                        }
                        Text("\(title.requiredVisits)か所〜")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("🔒")
                            .font(.title3)
                    }
                }
                .padding(.vertical, 4)
                .opacity(isUnlocked ? 1.0 : 0.6)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Badge Collection View
struct BadgeCollectionView: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("バッジコレクション")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.unlockedBadgeIds.count)/\(Badge.all.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                ForEach(viewModel.badges) { badge in
                    BadgeCell(badge: badge)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct BadgeCell: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? badge.color.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 56, height: 56)

                Image(systemName: badge.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(badge.isUnlocked ? badge.color : Color(.systemGray3))

                if !badge.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.systemGray3))
                        .offset(x: 16, y: 16)
                }
            }
            Text(badge.name)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(badge.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: 80)
    }
}

// MARK: - Stats Detail View
struct StatsDetailView: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("詳細統計")
                .font(.headline)

            VStack(spacing: 8) {
                StatRow(label: "訪問した温泉",     value: "\(viewModel.uniqueVisitCount)か所", icon: "mappin.circle.fill", color: .orange)
                StatRow(label: "総入浴回数",        value: "\(viewModel.totalVisitCount)回",   icon: "drop.fill",           color: .blue)
                StatRow(label: "制覇した都道府県",   value: "\(viewModel.visitedPrefectures.count)都道府県", icon: "map.fill", color: .green)
                StatRow(label: "獲得したバッジ",    value: "\(viewModel.unlockedBadgeIds.count)個",        icon: "star.fill", color: .yellow)

                if let mostVisited = viewModel.visits
                    .reduce(into: [UUID: Int]()) { $0[$1.onsenId, default: 0] += 1 }
                    .max(by: { $0.value < $1.value }),
                   let onsen = viewModel.allOnsens.first(where: { $0.id == mostVisited.key }) {
                    StatRow(
                        label: "最多訪問の温泉",
                        value: "\(onsen.name) (\(mostVisited.value)回)",
                        icon: "heart.fill",
                        color: .red
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Share Achievement View
struct ShareAchievementView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // シェア用カード
                AchievementShareCard()
                    .padding(.horizontal)

                Text("この記録をシェアして友達と楽しもう！")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ShareLink(item: viewModel.shareText()) {
                    Label("シェアする", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal)
            }
            .padding(.top, 24)
            .navigationTitle("実績をシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Achievement Share Card（シェア用カード）
struct AchievementShareCard: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        let title = viewModel.currentTitle

        VStack(spacing: 16) {
            HStack {
                Text("♨️ OnsenMap")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                Spacer()
            }

            VStack(spacing: 8) {
                Image(systemName: title.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(title.color)

                Text(viewModel.userName)
                    .font(.headline)

                Text("の温泉記録")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                VStack {
                    Text("\(viewModel.uniqueVisitCount)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("か所").font(.caption).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(viewModel.visitedPrefectures.count)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("都道府県").font(.caption).foregroundStyle(.secondary)
                }
            }

            Text(title.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(title.color)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(title.color.opacity(0.15))
                .cornerRadius(20)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), title.color.opacity(0.1)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
