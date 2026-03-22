import SwiftUI
import MapKit

// MARK: - Map Tab View
struct MapTabView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @StateObject private var locationVM = LocationViewModel()

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0), // 日本中心
            span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
        )
    )
    @State private var selectedOnsen: Onsen? = nil
    @State private var showingDetail = false
    @State private var showingSearch = false
    @State private var searchQuery = ""
    @State private var mapStyle: MapStyle = .standard

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // ─── Map ───
                Map(position: $cameraPosition, selection: .constant(nil)) {
                    // ユーザー位置
                    UserAnnotation()

                    // 温泉ピン
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

                // ─── 下部バナー広告 ───
                VStack(spacing: 0) {
                    AdBannerView(adUnitID: "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX")
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("温泉マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSearch.toggle()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            mapStyle = .standard
                        } label: {
                            Label("標準", systemImage: "map")
                        }
                        Button {
                            mapStyle = .hybrid
                        } label: {
                            Label("航空写真+地図", systemImage: "globe")
                        }
                        Button {
                            mapStyle = .imagery
                        } label: {
                            Label("航空写真", systemImage: "camera")
                        }
                    } label: {
                        Image(systemName: "map.fill")
                    }
                }
            }
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
            .onAppear {
                locationVM.requestPermission()
            }
        }
    }
}

// MARK: - Onsen Pin View
struct OnsenPinView: View {
    let onsen: Onsen
    let isVisited: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isVisited ? Color.orange : Color.blue)
                .frame(width: 36, height: 36)
                .shadow(radius: 3)

            Text(onsen.onsenType.icon)
                .font(.system(size: 18))
        }
        .overlay(
            isVisited ?
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 36, height: 36) : nil
        )
    }
}

// MARK: - Map Search View
struct MapSearchView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @Binding var cameraPosition: MapCameraPosition
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section("都道府県で絞り込む") {
                        ForEach(viewModel.prefectures, id: \.self) { pref in
                            Button {
                                viewModel.selectedPrefecture = pref
                                dismiss()
                            } label: {
                                HStack {
                                    Text(pref)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.selectedPrefecture == pref {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section("検索結果") {
                        ForEach(viewModel.filteredOnsens.filter {
                            $0.name.contains(query) || $0.address.contains(query)
                        }) { onsen in
                            Button {
                                cameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: onsen.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                    )
                                )
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(onsen.onsenType.icon)
                                        Text(onsen.name)
                                            .foregroundStyle(.primary)
                                            .fontWeight(.medium)
                                    }
                                    Text(onsen.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "温泉名・住所で検索")
            .navigationTitle("温泉を探す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
                if viewModel.selectedPrefecture != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("絞り込み解除") {
                            viewModel.selectedPrefecture = nil
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}
