import SwiftUI

// MARK: - Content View（メインのタブビュー）
struct ContentView: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        TabView {
            // ─── マップ ───
            MapTabView()
                .tabItem {
                    Label("マップ", systemImage: "map.fill")
                }

            // ─── 日記 ───
            DiaryTabView()
                .tabItem {
                    Label("日記", systemImage: "book.fill")
                }

            // ─── 称号・バッジ ───
            AchievementsTabView()
                .tabItem {
                    Label("称号", systemImage: "trophy.fill")
                }

            // ─── プロフィール ───
            ProfileTabView()
                .tabItem {
                    Label("マイページ", systemImage: "person.fill")
                }
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .environmentObject(OnsenViewModel())
}
