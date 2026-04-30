import SwiftUI

// MARK: - Profile Tab View
struct ProfileTabView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @ObservedObject private var store = StoreManager.shared
    @State private var showingNameEdit = false
    @State private var showingShare = false
    @State private var showingPaywall = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                // ─── ユーザー情報 ───
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.6), .red.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                            Image(systemName: viewModel.currentTitle.icon)
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.userName)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(viewModel.currentTitle.name)
                                .font(.subheadline)
                                .foregroundStyle(viewModel.currentTitle.color)
                            Text("\(viewModel.uniqueVisitCount)か所制覇")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Button {
                            newName = viewModel.userName
                            showingNameEdit = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // ─── マイ統計 ───
                Section("マイ統計") {
                    NavigationLink {
                        StatsDetailFullView()
                    } label: {
                        Label("詳細統計を見る", systemImage: "chart.bar.fill")
                    }

                    NavigationLink {
                        VisitedPrefecturesView()
                    } label: {
                        Label("制覇した都道府県 (\(viewModel.visitedPrefectures.count))", systemImage: "map.fill")
                    }
                }

                // ─── iCloud 同期 ───
                Section("iCloud同期") {
                    CloudSyncRow()
                }

                // ─── OnsenMap Pro ───
                Section {
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.orange, .red],
                                                         startPoint: .topLeading,
                                                         endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.white)
                                    .font(.subheadline)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.isPro ? "OnsenMap Pro（購入済み）" : "OnsenMap Pro")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(store.isPro
                                     ? "ご利用ありがとうございます！"
                                     : "広告非表示・写真無制限・CSVエクスポート")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.isPro {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // ─── 友達とシェア ───
                Section("友達とシェア") {
                    Button {
                        showingShare = true
                    } label: {
                        Label("シェアハブを開く", systemImage: "person.2.wave.2.fill")
                            .foregroundStyle(.orange)
                    }
                    Text("画像シェア・QRコード・記録のエクスポート/インポートができます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // ─── 広告 ───
                Section {
                    AdBannerView(adUnitID: "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX")
                        .listRowInsets(EdgeInsets())
                }

                // ─── アプリ情報 ───
                Section("アプリについて") {
                    HStack {
                        Label("バージョン", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        openReviewPage()
                    } label: {
                        Label("App Store でレビュー", systemImage: "star.bubble")
                            .foregroundStyle(.yellow)
                    }

                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                    }

                    Link(destination: URL(string: "https://example.com/terms")!) {
                        Label("利用規約", systemImage: "doc.text")
                    }
                }

                // ─── データ管理 ───
                Section("データ管理") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("データ管理", systemImage: "externaldrive.fill")
                    }
                }
            }
            .navigationTitle("プロフィール")
            .sheet(isPresented: $showingShare) {
                SocialShareView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert("名前を変更", isPresented: $showingNameEdit) {
                TextField("ニックネーム", text: $newName)
                Button("変更") {
                    if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                        viewModel.updateUserName(newName.trimmingCharacters(in: .whitespaces))
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("表示名を入力してください")
            }
        }
    }

    private func openReviewPage() {
        // App Store の URL（ストア公開後に実際の App ID に変更）
        if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Stats Detail Full View
struct StatsDetailFullView: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var avgRating: Double {
        let ratings = viewModel.visits.map { Double($0.rating) }
        return ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)
    }

    var mostPopularMood: Visit.Mood? {
        let moods = viewModel.visits.map { $0.mood }
        return moods.max(by: { a, b in
            moods.filter { $0 == a }.count < moods.filter { $0 == b }.count
        })
    }

    var body: some View {
        List {
            Section("訪問統計") {
                StatRow(label: "訪問した温泉数（ユニーク）", value: "\(viewModel.uniqueVisitCount)か所",  icon: "mappin.circle.fill", color: .orange)
                StatRow(label: "総入浴回数",                value: "\(viewModel.totalVisitCount)回",    icon: "drop.fill",           color: .blue)
                StatRow(label: "制覇した都道府県",           value: "\(viewModel.visitedPrefectures.count)都道府県", icon: "map.fill", color: .green)
                StatRow(label: "平均評価",
                        value: String(format: "%.1f ★", avgRating),
                        icon: "star.fill", color: .yellow)
            }

            if let mood = mostPopularMood {
                Section("気分統計") {
                    StatRow(label: "一番多かった気分",
                            value: "\(mood.icon) \(mood.rawValue)",
                            icon: "face.smiling", color: .pink)
                }
            }

            Section("泉質ランキング（訪問済みの温泉）") {
                ForEach(springQualityRanking(), id: \.key) { kv in
                    HStack {
                        Text(kv.key)
                            .font(.subheadline)
                        Spacer()
                        Text("\(kv.value)か所")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("詳細統計")
    }

    private func springQualityRanking() -> [(key: String, value: Int)] {
        var counts: [String: Int] = [:]
        for onsen in viewModel.visitedOnsens {
            if let quality = onsen.springQuality {
                counts[quality, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { (key: $0.key, value: $0.value) }
    }
}

// MARK: - Visited Prefectures View
struct VisitedPrefecturesView: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    let allPrefectures = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
        "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
        "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
        "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]

    var body: some View {
        List {
            Section {
                HStack {
                    Text("制覇済み")
                    Spacer()
                    Text("\(viewModel.visitedPrefectures.count) / 47")
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
            }

            ForEach(allPrefectures, id: \.self) { pref in
                let isVisited = viewModel.visitedPrefectures.contains(pref)
                let count = viewModel.visitedOnsens.filter { $0.prefecture == pref }.count

                HStack {
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isVisited ? .orange : Color(.systemGray4))
                    Text(pref)
                        .foregroundStyle(isVisited ? .primary : .secondary)
                    Spacer()
                    if count > 0 {
                        Text("\(count)か所")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle("制覇した都道府県")
    }
}

// MARK: - Data Management View
struct DataManagementView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @ObservedObject private var store = StoreManager.shared
    @State private var showingClearAlert = false
    @State private var showingPaywall = false
    @State private var exportedFileURL: URL?

    var body: some View {
        List {
            Section {
                HStack {
                    Label("日記エントリー数", systemImage: "book.fill")
                    Spacer()
                    Text("\(viewModel.visits.count)件")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("訪問した温泉数", systemImage: "mappin.fill")
                    Spacer()
                    Text("\(viewModel.uniqueVisitCount)か所")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("保存データ")
            }

            Section {
                Button {
                    if store.isPro {
                        if let url = viewModel.exportVisitsAsCSV() {
                            exportedFileURL = url
                        }
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    HStack {
                        Label("CSV エクスポート", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.primary)
                        Spacer()
                        if !store.isPro {
                            Label("Pro", systemImage: "crown.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } header: {
                Text("エクスポート")
            } footer: {
                Text(store.isPro
                     ? "全訪問記録を CSV ファイルとして書き出します。"
                     : "Pro にアップグレードすると CSV エクスポートが利用できます。")
            }

            Section {
                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Label("すべてのデータを削除", systemImage: "trash.fill")
                }
            } header: {
                Text("危険な操作")
            } footer: {
                Text("削除したデータは元に戻せません。")
            }
        }
        .navigationTitle("データ管理")
        .alert("データを削除しますか？", isPresented: $showingClearAlert) {
            Button("削除する", role: .destructive) {
                // データクリア処理
                viewModel.visits.forEach { viewModel.deleteVisit($0) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべての訪問記録と日記が削除されます。この操作は取り消せません。")
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(item: Binding<IdentifiedURL?>(
            get: { exportedFileURL.map { IdentifiedURL(url: $0) } },
            set: { exportedFileURL = $0?.url }
        )) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
    }
}

// MARK: - Identified URL（sheet(item:) 用ラッパー）
private struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - iCloud Sync Row
struct CloudSyncRow: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @ObservedObject private var sync = CloudKitSyncService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloudに記録を同期")
                        .font(.subheadline)
                    Text(sync.state.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await viewModel.initialCloudSync() }
                } label: {
                    if case .syncing = sync.state {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.orange)
                    }
                }
                .disabled(isSyncing)
            }

            if case .unavailable = sync.state {
                Text("「設定 > iCloud」からログインすると、機種変更してもデータが引き継げます。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var isSyncing: Bool {
        if case .syncing = sync.state { return true }
        return false
    }

    private var iconName: String {
        switch sync.state {
        case .synced:        return "checkmark.icloud.fill"
        case .syncing:       return "icloud.and.arrow.down"
        case .failed:        return "exclamationmark.icloud.fill"
        case .unavailable:   return "icloud.slash"
        case .idle:          return "icloud"
        }
    }

    private var iconColor: Color {
        switch sync.state {
        case .synced:        return .green
        case .syncing:       return .orange
        case .failed:        return .red
        case .unavailable:   return .gray
        case .idle:          return .secondary
        }
    }
}
