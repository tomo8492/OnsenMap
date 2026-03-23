import SwiftUI

@main
struct OnsenMapApp: App {

    @StateObject private var viewModel = OnsenViewModel()

    init() {
        // ─── Google AdMob 初期化 ───
        // AdMob SDK を追加した後に下記のコメントを外してください:
        // GADMobileAds.sharedInstance().start(completionHandler: nil)

        // TabBar の外観設定
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
