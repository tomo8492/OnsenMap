import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        TabView {
            MapTabView()
                .tabItem { Label("マップ",   systemImage: "map.fill") }

            DiaryTabView()
                .tabItem { Label("日記",     systemImage: "book.fill") }

            AchievementsTabView()
                .tabItem { Label("称号",     systemImage: "trophy.fill") }

            ProfileTabView()
                .tabItem { Label("マイページ", systemImage: "person.fill") }
        }
        .tint(.orange)
        // バッジ解放祝福オーバーレイ
        .overlay(alignment: .top) {
            if let badge = viewModel.newlyUnlockedBadges.first {
                BadgeUnlockBanner(badge: badge)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.newlyUnlockedBadges.first?.id)
    }
}

// MARK: - Badge Unlock Banner
struct BadgeUnlockBanner: View {
    let badge: Badge
    @EnvironmentObject var viewModel: OnsenViewModel
    @State private var isVisible = true

    var body: some View {
        Group {
            if isVisible {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(badge.color.opacity(0.25))
                            .frame(width: 48, height: 48)
                        Image(systemName: badge.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(badge.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🎉 バッジ解放！")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(badge.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(badge.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .padding(.horizontal)
                .padding(.top, 8)
                .onAppear {
                    // ハプティックフィードバック
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // 3秒後に自動消去
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { dismiss() }
                }
            }
        }
    }

    private func dismiss() {
        withAnimation { isVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            viewModel.newlyUnlockedBadges.removeFirst()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(OnsenViewModel())
        .environmentObject(GameCenterService.shared)
}
