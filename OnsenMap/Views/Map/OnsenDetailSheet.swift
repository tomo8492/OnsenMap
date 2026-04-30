import SwiftUI
import MapKit

// MARK: - Onsen Detail Sheet
struct OnsenDetailSheet: View {
    let onsen: Onsen
    @EnvironmentObject var viewModel: OnsenViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddVisit = false
    @State private var showingAllVisits = false

    var isVisited: Bool { viewModel.isVisited(onsen) }
    var visitHistory: [Visit] { viewModel.visitsFor(onsen) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ─── ヘッダー画像 ───
                    ZStack(alignment: .bottomLeading) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: isVisited
                                        ? [.orange.opacity(0.8), .red.opacity(0.6)]
                                        : [.blue.opacity(0.8), .cyan.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 160)
                            .overlay(
                                Text(onsen.onsenType.icon)
                                    .font(.system(size: 72))
                                    .opacity(0.3)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            if isVisited {
                                Label("訪問済み", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.9))
                                    .cornerRadius(20)
                            }
                            Text(onsen.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text(onsen.onsenType.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding()
                    }

                    VStack(alignment: .leading, spacing: 16) {

                        // ─── アクションボタン ───
                        HStack(spacing: 12) {
                            // 行った！ボタン
                            Button {
                                showingAddVisit = true
                            } label: {
                                Label(isVisited ? "また行った！" : "行った！",
                                      systemImage: isVisited ? "plus.circle.fill" : "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isVisited ? Color.orange : Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                                    .fontWeight(.semibold)
                            }

                            // 経路案内ボタン
                            Button {
                                openInMaps()
                            } label: {
                                Label("経路", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.top, 4)

                        // ─── 基本情報 ───
                        DetailSection(title: "基本情報") {
                            InfoRow(icon: "mappin.circle.fill", color: .red, title: "住所") {
                                Button {
                                    openInMaps()
                                } label: {
                                    Text(onsen.address)
                                        .foregroundStyle(.blue)
                                        .multilineTextAlignment(.leading)
                                }
                            }

                            if let hours = onsen.openingHours {
                                InfoRow(icon: "clock.fill", color: .blue, title: "営業時間") {
                                    Text(hours)
                                }
                            }

                            if let fee = onsen.entryFee {
                                InfoRow(icon: "yensign.circle.fill", color: .green, title: "料金") {
                                    Text(fee)
                                }
                            }

                            if let holiday = onsen.regularHoliday {
                                InfoRow(icon: "calendar.badge.minus", color: .orange, title: "定休日") {
                                    Text(holiday)
                                }
                            }

                            if let phone = onsen.phoneNumber {
                                InfoRow(icon: "phone.fill", color: .green, title: "電話番号") {
                                    Button {
                                        if let url = URL(string: "tel:\(phone.replacingOccurrences(of: "-", with: ""))") {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        Text(phone).foregroundStyle(.blue)
                                    }
                                }
                            }

                            InfoRow(icon: "car.fill", color: .gray, title: "駐車場") {
                                Text(onsen.hasParking ? "あり" : "なし")
                            }
                        }

                        // ─── 泉質・説明 ───
                        if !onsen.description.isEmpty || onsen.springQuality != nil {
                            DetailSection(title: "温泉について") {
                                if let quality = onsen.springQuality {
                                    InfoRow(icon: "drop.fill", color: .cyan, title: "泉質") {
                                        Text(quality)
                                    }
                                }
                                if !onsen.description.isEmpty {
                                    Text(onsen.description)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                        }

                        // ─── 施設 ───
                        if !onsen.facilities.isEmpty {
                            DetailSection(title: "施設・設備") {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                    ForEach(onsen.facilities, id: \.self) { facility in
                                        Label(facility, systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }

                        // ─── 訪問履歴 ───
                        if !visitHistory.isEmpty {
                            DetailSection(title: "訪問記録 (\(visitHistory.count)回)") {
                                ForEach(visitHistory.prefix(3)) { visit in
                                    VisitSummaryRow(visit: visit)
                                    if visit.id != visitHistory.prefix(3).last?.id {
                                        Divider()
                                    }
                                }
                                if visitHistory.count > 3 {
                                    Button("すべて見る (\(visitHistory.count)件)") {
                                        showingAllVisits = true
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                    .padding(.top, 4)
                                }
                            }
                        }

                        // ─── 近くの宿（楽天トラベル アフィリエイト） ───
                        NearbyHotelsSection(onsen: onsen)

                        // ─── 広告 ───
                        AdRectangleView()
                            .padding(.vertical, 8)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        share()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingAddVisit) {
            AddVisitView(onsen: onsen)
        }
        .sheet(isPresented: $showingAllVisits) {
            VisitHistoryView(onsen: onsen)
        }
    }

    // MARK: - Actions
    private func openInMaps() {
        // まず Google Maps を試し、なければ Apple Maps にフォールバック
        let encodedName = onsen.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let googleMapsURL = URL(string: "comgooglemaps://?q=\(encodedName)&center=\(onsen.latitude),\(onsen.longitude)")
        let appleMapsURL = URL(string: "maps://?q=\(encodedName)&ll=\(onsen.latitude),\(onsen.longitude)")

        if let googleURL = googleMapsURL,
           UIApplication.shared.canOpenURL(googleURL) {
            UIApplication.shared.open(googleURL)
        } else if let appleURL = appleMapsURL {
            UIApplication.shared.open(appleURL)
        }
    }

    private func share() {
        let text = """
        🌊 \(onsen.name) に行ってきました！
        📍 \(onsen.address)
        \(onsen.onsenType.icon) \(onsen.onsenType.rawValue)

        #OnsenMap #温泉 #\(onsen.prefecture)
        """
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Detail Section
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Info Row
struct InfoRow<Content: View>: View {
    let icon: String
    let color: Color
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            content
                .font(.subheadline)
        }
    }
}

// MARK: - Visit Summary Row
struct VisitSummaryRow: View {
    let visit: Visit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(visit.mood.icon)
                    Text(visit.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                if !visit.notes.isEmpty {
                    Text(visit.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            StarRatingView(rating: visit.rating, size: 12)
        }
    }
}

// MARK: - Nearby Hotels Section（楽天トラベル + じゃらん アフィリエイト）

struct NearbyHotelsSection: View {
    let onsen: Onsen

    enum Provider: String, CaseIterable, Identifiable {
        case rakuten = "楽天トラベル"
        case jalan   = "じゃらん"
        var id: String { rawValue }
    }

    @State private var selectedProvider: Provider = .rakuten
    @State private var hotels: [RakutenHotel] = []
    @State private var loadState: LoadState = .idle

    enum LoadState {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
        case notConfigured
    }

    var body: some View {
        DetailSection(title: "この温泉の近くに泊まる") {
            // ─── プロバイダー切り替え ───
            Picker("予約サイト", selection: $selectedProvider) {
                ForEach(Provider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedProvider) { _, _ in
                // タブ切り替え時に状態リセット
                hotels = []
                loadState = .idle
            }

            // ─── プロバイダー別コンテンツ ───
            switch selectedProvider {
            case .rakuten: rakutenContent
            case .jalan:   jalanContent
            }
        }
    }

    // MARK: - Rakuten
    @ViewBuilder
    private var rakutenContent: some View {
        switch loadState {
        case .idle:
            Button {
                Task { await loadRakuten() }
            } label: {
                searchCTA(provider: .rakuten,
                          subtitle: "楽天トラベルで周辺3km以内を検索")
            }
            .buttonStyle(.plain)

        case .loading:
            loadingRow

        case .loaded:
            VStack(spacing: 8) {
                ForEach(hotels) { hotel in
                    HotelRow(hotel: hotel)
                    if hotel.id != hotels.last?.id { Divider() }
                }
            }
            rakutenFallbackLink
            attributionFooter(text: "提供: 楽天トラベル")

        case .empty:
            Text("半径3km以内に楽天トラベル掲載の宿が見つかりませんでした。")
                .font(.caption)
                .foregroundStyle(.secondary)
            rakutenFallbackLink
            attributionFooter(text: "提供: 楽天トラベル")

        case .failed(let msg):
            Text("一覧の取得に失敗しました: \(msg)")
                .font(.caption2)
                .foregroundStyle(.red)
            rakutenFallbackLink
            attributionFooter(text: "提供: 楽天トラベル")

        case .notConfigured:
            Text("楽天トラベルで「\(onsen.name)」付近の宿を検索できます。")
                .font(.caption)
                .foregroundStyle(.secondary)
            rakutenFallbackLink
            attributionFooter(text: "提供: 楽天トラベル")
        }
    }

    // MARK: - Jalan
    @ViewBuilder
    private var jalanContent: some View {
        VStack(spacing: 10) {
            Text("じゃらん net で「\(onsen.name)」付近の宿を検索できます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Link(destination: JalanTravelService.shared.nearbySearchURL(for: onsen)) {
                HStack {
                    Image(systemName: "map.fill")
                    Text("半径3km以内の宿を探す")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(red: 1.0, green: 0.4, blue: 0.0))
                .cornerRadius(10)
            }

            Link(destination: JalanTravelService.shared.searchURL(for: onsen)) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("「\(onsen.name)」を名前で検索")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            attributionFooter(text: "提供: じゃらん net")
        }
    }

    // MARK: - Helpers

    private func searchCTA(provider: Provider, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bed.double.fill")
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(provider == .rakuten
                    ? Color(red: 0.75, green: 0.0, blue: 0.0)
                    : Color(red: 1.0, green: 0.4, blue: 0.0))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("近くの宿を探す")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.8)
            Text("検索中...").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var rakutenFallbackLink: some View {
        Link(destination: RakutenTravelService.shared.fallbackSearchURL(for: onsen)) {
            HStack {
                Image(systemName: "arrow.up.right.square.fill")
                Text("楽天トラベルで「\(onsen.name)」を探す")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(red: 0.75, green: 0.0, blue: 0.0))
            .cornerRadius(10)
        }
        .padding(.top, 6)
    }

    private func attributionFooter(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loader
    private func loadRakuten() async {
        guard AffiliateConfig.isRakutenConfigured else {
            loadState = .notConfigured
            return
        }
        loadState = .loading
        do {
            let result = try await RakutenTravelService.shared.searchHotels(
                near: onsen.coordinate,
                radiusKm: 3.0,
                hits: 10
            )
            hotels = result
            loadState = result.isEmpty ? .empty : .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Hotel Row

struct HotelRow: View {
    let hotel: RakutenHotel

    var body: some View {
        Link(destination: hotel.infoUrl) {
            HStack(alignment: .top, spacing: 10) {
                AsyncImage(url: hotel.thumbnailUrl ?? hotel.imageUrl) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .empty:
                        ProgressView().scaleEffect(0.7)
                    default:
                        Image(systemName: "bed.double.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
                .background(Color(.systemGray6))
                .clipped()
                .cornerRadius(6)

                VStack(alignment: .leading, spacing: 3) {
                    Text(hotel.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let avg = hotel.reviewAverage,
                       let cnt = hotel.reviewCount, cnt > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", avg))
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Text("(\(cnt))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let charge = hotel.minCharge {
                        Text("¥\(charge.formatted())〜 / 室")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    } else if let access = hotel.access, !access.isEmpty {
                        Text(access)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visit History View
struct VisitHistoryView: View {
    let onsen: Onsen
    @EnvironmentObject var viewModel: OnsenViewModel
    @Environment(\.dismiss) private var dismiss

    var visits: [Visit] { viewModel.visitsFor(onsen) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visits) { visit in
                    VisitSummaryRow(visit: visit)
                        .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    indexSet.forEach { viewModel.deleteVisit(visits[$0]) }
                }
            }
            .navigationTitle("\(onsen.name) の訪問記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
