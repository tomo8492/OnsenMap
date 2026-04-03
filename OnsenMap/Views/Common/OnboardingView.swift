import SwiftUI

// MARK: - Onboarding View（初回起動チュートリアル）
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "♨️",
            title: "OnsenMap へようこそ",
            description: "日本全国3,300か所以上の温泉を\n地図で発見・記録できるアプリです。\n秘湯から有名温泉地まで網羅！",
            accentColor: .orange
        ),
        OnboardingPage(
            icon: "🗺️",
            title: "マップで温泉を探す",
            description: "ピンをタップすると詳細情報が表示されます。\n\n🔵 未訪問　🟠 訪問済み\n🟣 秘湯　　🩷 行きたい！",
            accentColor: .blue
        ),
        OnboardingPage(
            icon: "📖",
            title: "日記に記録しよう",
            description: "温泉に行ったら「行った！」ボタンで\n評価・気分・写真を記録できます。\n「行きたい！」でウィッシュリスト登録も！",
            accentColor: .green
        ),
        OnboardingPage(
            icon: "🏆",
            title: "称号でゲームを楽しもう",
            description: "訪問数に応じて称号が変わります。\n「宮城の温泉仙人」など\n自分だけの称号を作ることも！",
            accentColor: .purple
        ),
        OnboardingPage(
            icon: "🌍",
            title: "世界ランキングに参加",
            description: "Game Center で全国の\n温泉ハンターとスコアを競えます。\n友達と記録をシェアして盛り上がろう！",
            accentColor: .orange
        ),
    ]

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [pages[currentPage].accentColor.opacity(0.15), Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // ─── ページコンテンツ ───
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        OnboardingPageView(page: pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // ─── ページインジケーター ───
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? pages[currentPage].accentColor : Color(.systemGray4))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // ─── ボタン ───
                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            Text("次へ")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(pages[currentPage].accentColor)
                                .foregroundStyle(.white)
                                .cornerRadius(14)
                        }

                        Button("スキップ") {
                            hasSeenOnboarding = true
                        }
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    } else {
                        Button {
                            hasSeenOnboarding = true
                        } label: {
                            Label("はじめる！", systemImage: "arrow.right.circle.fill")
                                .fontWeight(.bold)
                                .font(.title3)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(pages[currentPage].accentColor)
                                .foregroundStyle(.white)
                                .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text(page.icon)
                .font(.system(size: 90))
                .shadow(color: page.accentColor.opacity(0.3), radius: 16)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
