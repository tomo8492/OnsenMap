import SwiftUI

@main
struct OnsenMapApp: App {

    @StateObject private var viewModel     = OnsenViewModel()
    @StateObject private var gameCenter    = GameCenterService.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        // Google AdMob 初期化（SDK 追加後にコメントを外す）
        // GADMobileAds.sharedInstance().start(completionHandler: nil)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance  = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    ContentView()
                } else {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                }
            }
            .environmentObject(viewModel)
            .environmentObject(gameCenter)
            .task {
                // Game Center 認証（起動時に一度だけ）
                GameCenterService.shared.authenticateOnLaunch()
                // 通知許可をリクエスト
                await NotificationService.shared.requestPermission()
            }
        }
    }
}
