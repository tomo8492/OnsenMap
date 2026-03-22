import SwiftUI
import MapKit

// MARK: - Map Tab View
struct MapTabView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @StateObject private var locationVM = LocationViewModel()

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0),
            span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
        )
    )
    @State private var selectedOnsen: Onsen?
    @State private var showingDetail    = false
    @State private var showingSearch    = false
    @State private var showingFilter    = false
    @State private var mapStyle: MapStyle = .standard

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // ─── Map ───
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    ForEach(viewModel.filteredOnsens) { onsen in
                        Annotation(onsen.name, coordinate: onsen.coordinate) {
                            OnsenPinView(
                                onsen: onsen,
                                isVisited: viewModel.isVisited(onsen)
                            )
                            .onTapGesture {
                                selectedOnsen = onsen
                                showingDetail = true
                            }
                        }
                    }
                }
                .mapStyle(mapStyle)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .ignoresSafeArea(edges: .top)

                // ─── 下部オーバーレイ ───
                VStack(spacing: 0) {
                    // データ読み込みバナー
                    DataLoadingBanner()

                    // フィルターチップ
                    if viewModel.hasActiveFilters {
                        ActiveFilterBar()
                    }

                    // 広告バナー
                    AdBannerView(adUnitID: "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX")
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("温泉マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingDetail) {
                if let onsen = selectedOnsen {
                    OnsenDetailSheet(onsen: onsen)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingSearch) {
                MapSearchView(cameraPosition: $cameraPosition)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingFilter) {
                MapFilterView()
                    .presentationDetents([.medium])
            }
            .onAppear {
                locationVM.requestPermission()
                // 初回起動時にデータ取得を開始
                if case .idle = viewModel.loadingState {
                    Task { await viewModel.fetchFullDatabase() }
                }
            }
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingSearch.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 4) {
                // フィルターボタン
                Button {
                    showingFilter.toggle()
                } label: {
                    Image(systemName: viewModel.hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(viewModel.hasActiveFilters ? .orange : .primary)
                }

                // マップスタイル
                Menu {
                    Button { mapStyle = .standard } label: {
                        Label("標準", systemImage: "map")
                    }
                    Button { mapStyle = .hybrid } label: {
                        Label("航空写真+地図", systemImage: "globe")
                    }
                    Button { mapStyle = .imagery } label: {
                        Label("航空写真", systemImage: "camera")
                    }
                } label: {
                    Image(systemName: "map.fill")
                }
            }
        }
    }
}

// MARK: - Data Loading Banner
struct DataLoadingBanner: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        switch viewModel.loadingState {
        case .idle:
            // 初回取得ボタン
            Button {
                Task { await viewModel.fetchFullDatabase() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.orange)
                    Text("全国の温泉データを取得する")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("約2,500か所")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

        case .loading(let progress, let total):
            VStack(spacing: 4) {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(viewModel.loadingState.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ProgressView(value: Double(progress), total: Double(total))
                    .tint(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

        case .loaded(let count):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("\(count.formatted())か所を表示中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await viewModel.refreshDatabase() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

        case .failed(let msg):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                Spacer()
                Button("再試行") {
                    Task { await viewModel.fetchFullDatabase() }
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Active Filter Bar
struct ActiveFilterBar: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if viewModel.showSecretOnly {
                    FilterChip(label: "秘湯のみ", icon: "mountain.2.fill") {
                        viewModel.showSecretOnly = false
                    }
                }
                if let pref = viewModel.selectedPrefecture {
                    FilterChip(label: pref, icon: "mappin.circle") {
                        viewModel.selectedPrefecture = nil
                    }
                }
                ForEach(Array(viewModel.selectedTypes), id: \.self) { type in
                    FilterChip(label: type.rawValue, icon: "drop.fill") {
                        viewModel.selectedTypes.remove(type)
                    }
                }
                if !viewModel.searchText.isEmpty {
                    FilterChip(label: "「\(viewModel.searchText)」", icon: "magnifyingglass") {
                        viewModel.searchText = ""
                    }
                }

                Button("すべてクリア") {
                    viewModel.clearFilters()
                }
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.leading, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(label).font(.caption)
            Button { onRemove() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(12)
        .foregroundStyle(.orange)
    }
}

// MARK: - Onsen Pin View
struct OnsenPinView: View {
    let onsen: Onsen
    let isVisited: Bool

    var isSecret: Bool { onsen.facilities.contains("秘湯") }

    var pinColor: Color {
        if isVisited    { return .orange }
        if isSecret     { return .purple }
        return .blue
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: 36, height: 36)
                .shadow(radius: 3)

            Text(onsen.onsenType.icon)
                .font(.system(size: 18))
        }
        .overlay(
            isVisited
                ? Circle().stroke(Color.white, lineWidth: 2).frame(width: 36, height: 36)
                : nil
        )
        // 秘湯は小さい ★ マークを付加
        .overlay(
            isSecret && !isVisited
                ? Text("★")
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
                    .offset(x: 12, y: -12)
                : nil
        )
    }
}

// MARK: - Map Filter View（フィルター）
struct MapFilterView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // ─── 秘湯フィルター ───
                Section {
                    Toggle(isOn: $viewModel.showSecretOnly) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("秘湯のみ表示")
                                Text("自然湧出・山奥・アクセス困難な温泉")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "mountain.2.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                    .tint(.purple)
                }

                // ─── 種別フィルター ───
                Section("温泉の種別") {
                    ForEach(Onsen.OnsenType.allCases, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get:  { viewModel.selectedTypes.contains(type) },
                            set:  { if $0 { viewModel.selectedTypes.insert(type) }
                                    else  { viewModel.selectedTypes.remove(type) } }
                        )) {
                            Label("\(type.icon) \(type.rawValue)", systemImage: "")
                        }
                        .tint(.orange)
                    }
                }

                // ─── 都道府県フィルター ───
                Section("都道府県") {
                    Picker("都道府県", selection: $viewModel.selectedPrefecture) {
                        Text("すべて").tag(Optional<String>(nil))
                        ForEach(viewModel.prefectures, id: \.self) { pref in
                            Text(pref).tag(Optional(pref))
                        }
                    }
                    .pickerStyle(.menu)
                }

                // ─── クリア ───
                if viewModel.hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            viewModel.clearFilters()
                            dismiss()
                        } label: {
                            Label("フィルターをすべてクリア", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .navigationTitle("絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Map Search View
struct MapSearchView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @Binding var cameraPosition: MapCameraPosition
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    var searchResults: [Onsen] {
        if query.isEmpty { return [] }
        let q = query
        return viewModel.allOnsens.filter {
            $0.name.contains(q) || $0.address.contains(q) ||
            $0.prefecture.contains(q) || ($0.springQuality ?? "").contains(q) ||
            $0.nameReading.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    // ─── 都道府県ショートカット ───
                    Section("都道府県で絞り込む") {
                        ForEach(viewModel.prefectures, id: \.self) { pref in
                            Button {
                                viewModel.selectedPrefecture = pref
                                dismiss()
                            } label: {
                                HStack {
                                    Text(pref).foregroundStyle(.primary)
                                    Spacer()
                                    let cnt = viewModel.allOnsens.filter { $0.prefecture == pref }.count
                                    Text("\(cnt)か所")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if viewModel.selectedPrefecture == pref {
                                        Image(systemName: "checkmark").foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }

                    // ─── 秘湯ショートカット ───
                    Section {
                        Button {
                            viewModel.showSecretOnly = true
                            dismiss()
                        } label: {
                            HStack {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("秘湯を探す")
                                            .foregroundStyle(.primary)
                                        Text("自然湧出・山奥の温泉 \(viewModel.secretOnsens.count)か所")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "mountain.2.fill")
                                        .foregroundStyle(.purple)
                                }
                                Spacer()
                            }
                        }
                    }

                } else {
                    // ─── 検索結果 ───
                    Section("\(searchResults.count)件の検索結果") {
                        ForEach(searchResults.prefix(50)) { onsen in
                            Button {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: onsen.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                ))
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Text(onsen.onsenType.icon)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(onsen.name)
                                                .foregroundStyle(.primary)
                                                .fontWeight(.medium)
                                            if onsen.facilities.contains("秘湯") {
                                                Text("秘湯")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text(onsen.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let quality = onsen.springQuality {
                                            Text("泉質: \(quality)")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                    }

                                    Spacer()

                                    if viewModel.isVisited(onsen) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "温泉名・住所・泉質で検索")
            .navigationTitle("温泉を探す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
                if viewModel.selectedPrefecture != nil || viewModel.showSecretOnly {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("絞り込み解除") {
                            viewModel.selectedPrefecture = nil
                            viewModel.showSecretOnly = false
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}
