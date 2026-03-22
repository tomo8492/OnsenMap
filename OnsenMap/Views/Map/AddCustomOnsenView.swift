import SwiftUI
import MapKit
import CoreLocation

// MARK: - Add Custom Onsen View
/// データベースにない温泉をユーザーが独自に追加できる画面
struct AddCustomOnsenView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @Environment(\.dismiss) private var dismiss

    // 基本情報
    @State private var name         = ""
    @State private var nameReading  = ""
    @State private var address      = ""
    @State private var prefecture   = ""
    @State private var description  = ""
    @State private var onsenType: Onsen.OnsenType = .hotSpring
    @State private var springQuality = ""

    // 位置情報
    @State private var latitude:  Double? = nil
    @State private var longitude: Double? = nil
    @State private var searchQuery       = ""
    @State private var geocodeResults: [MKMapItem] = []
    @State private var isGeocoding       = false
    @State private var pickedCoordinate: CLLocationCoordinate2D? = nil
    @State private var showingLocationPicker = false

    // 施設
    @State private var facilityText = ""
    @State private var facilities: [String] = []

    // その他
    @State private var phoneNumber   = ""
    @State private var website       = ""
    @State private var openingHours  = ""
    @State private var regularHoliday = ""
    @State private var entryFee      = ""
    @State private var hasParking    = true

    // バリデーション
    @State private var showingValidationAlert = false
    @State private var validationMessage      = ""

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        latitude != nil && longitude != nil
    }

    var body: some View {
        NavigationStack {
            Form {

                // ─── 名前 ───
                Section("温泉名 *") {
                    TextField("例: 〇〇温泉", text: $name)
                    TextField("ふりがな（任意）", text: $nameReading)
                }

                // ─── 種別 ───
                Section("種別 *") {
                    Picker("種別", selection: $onsenType) {
                        ForEach(Onsen.OnsenType.allCases, id: \.self) { type in
                            Text("\(type.icon) \(type.rawValue)").tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // ─── 位置情報 ───
                Section {
                    if let lat = latitude, let lon = longitude {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("座標設定済み")
                                    .fontWeight(.medium)
                                Text(String(format: "%.5f, %.5f", lat, lon))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("変更") { showingLocationPicker = true }
                                .font(.subheadline)
                        }
                    } else {
                        Button {
                            showingLocationPicker = true
                        } label: {
                            Label("住所から座標を取得 *", systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("位置情報 *")
                } footer: {
                    Text("マップに表示するために座標の設定が必要です")
                }

                // ─── 住所 ───
                Section("住所") {
                    TextField("都道府県", text: $prefecture)
                    TextField("住所（市区町村以降）", text: $address)
                }

                // ─── 泉質・説明 ───
                Section("泉質・紹介") {
                    TextField("泉質（例: 硫黄泉、アルカリ性単純温泉）", text: $springQuality)
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    Text("温泉の特徴・魅力を入力してください")
                                        .foregroundStyle(Color(.placeholderText))
                                        .allowsHitTesting(false)
                                        .padding(4)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                // ─── 施設 ───
                Section("施設・設備") {
                    ForEach(facilities, id: \.self) { f in
                        Text(f)
                    }
                    .onDelete { facilities.remove(atOffsets: $0) }

                    HStack {
                        TextField("例: 露天風呂、サウナ", text: $facilityText)
                        Button {
                            let f = facilityText.trimmingCharacters(in: .whitespaces)
                            if !f.isEmpty && !facilities.contains(f) {
                                facilities.append(f)
                                facilityText = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundStyle(.orange)
                        }
                    }
                }

                // ─── 営業情報 ───
                Section("営業情報") {
                    TextField("電話番号", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("ウェブサイト URL", text: $website)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("営業時間（例: 10:00〜22:00）", text: $openingHours)
                    TextField("定休日（例: 毎週火曜日）", text: $regularHoliday)
                    TextField("料金（例: 大人 600円）", text: $entryFee)
                    Toggle("駐車場あり", isOn: $hasParking)
                }
            }
            .navigationTitle("温泉を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(canSave ? .orange : .secondary)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    onSelect: { coord, fullAddress, pref in
                        latitude  = coord.latitude
                        longitude = coord.longitude
                        if address.isEmpty    { address    = fullAddress }
                        if prefecture.isEmpty { prefecture = pref }
                    }
                )
                .presentationDetents([.large])
            }
            .alert("入力内容を確認", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Save
    private func save() {
        guard let lat = latitude, let lon = longitude else {
            validationMessage = "座標を設定してください。"
            showingValidationAlert = true
            return
        }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "温泉名を入力してください。"
            showingValidationAlert = true
            return
        }

        let pref = prefecture.isEmpty ? PrefectureLookup.lookup(lat: lat, lon: lon) : prefecture
        let fullAddress = address.isEmpty ? pref : pref + address

        let onsen = Onsen(
            name:          name.trimmingCharacters(in: .whitespaces),
            nameReading:   nameReading,
            address:       fullAddress,
            prefecture:    pref,
            latitude:      lat,
            longitude:     lon,
            description:   description,
            onsenType:     onsenType,
            springQuality: springQuality.isEmpty ? nil : springQuality,
            facilities:    facilities,
            phoneNumber:   phoneNumber.isEmpty ? nil : phoneNumber,
            website:       website.isEmpty ? nil : website,
            openingHours:  openingHours.isEmpty ? nil : openingHours,
            regularHoliday: regularHoliday.isEmpty ? nil : regularHoliday,
            entryFee:      entryFee.isEmpty ? nil : entryFee,
            hasParking:    hasParking
        )
        viewModel.addCustomOnsen(onsen)
        dismiss()
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    let onSelect: (CLLocationCoordinate2D, String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText    = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching   = false

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        Text("住所や温泉名を入力して座標を取得します")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } else if isSearching {
                    Section {
                        HStack {
                            ProgressView()
                            Text("検索中...")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section("\(searchResults.count)件の検索結果") {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                let coord  = item.placemark.coordinate
                                let addr   = item.placemark.thoroughfare
                                           ?? item.placemark.locality
                                           ?? ""
                                let pref   = item.placemark.administrativeArea ?? ""
                                onSelect(coord, addr, pref)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "不明")
                                        .foregroundStyle(.primary)
                                        .fontWeight(.medium)
                                    if let addr = item.placemark.formattedAddress {
                                        Text(addr)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(String(format: "%.5f, %.5f",
                                                item.placemark.coordinate.latitude,
                                                item.placemark.coordinate.longitude))
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "住所・温泉名を入力")
            .onChange(of: searchText) { _, q in
                guard !q.isEmpty else { searchResults = []; return }
                Task { await search(query: q) }
            }
            .navigationTitle("座標を取得")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func search(query: String) async {
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0),
            span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
        )
        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
        isSearching = false
    }
}

// MARK: - MKPlacemark formatted address
private extension MKPlacemark {
    var formattedAddress: String? {
        [administrativeArea, locality, thoroughfare, subThoroughfare]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .nilIfEmpty
    }
}
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
