import SwiftUI

// MARK: - Diary Tab View（日記一覧）
struct DiaryTabView: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    @State private var sortOrder: SortOrder = .dateDesc
    @State private var filterRating: Int? = nil
    @State private var searchText = ""

    enum SortOrder: String, CaseIterable {
        case dateDesc  = "新しい順"
        case dateAsc   = "古い順"
        case ratingDesc = "評価が高い順"
        case nameAsc   = "名前順"
    }

    var displayVisits: [Visit] {
        var result = viewModel.visits

        // テキスト検索
        if !searchText.isEmpty {
            result = result.filter {
                $0.onsenName.contains(searchText) ||
                $0.notes.contains(searchText) ||
                $0.companions.joined().contains(searchText)
            }
        }

        // 評価フィルター
        if let r = filterRating {
            result = result.filter { $0.rating == r }
        }

        // ソート
        switch sortOrder {
        case .dateDesc:   result.sort { $0.date > $1.date }
        case .dateAsc:    result.sort { $0.date < $1.date }
        case .ratingDesc: result.sort { $0.rating > $1.rating }
        case .nameAsc:    result.sort { $0.onsenName < $1.onsenName }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.visits.isEmpty {
                    EmptyDiaryView()
                } else {
                    List {
                        // ─── 統計サマリー ───
                        Section {
                            StatsSummaryCard()
                        }
                        .listRowInsets(EdgeInsets())

                        // ─── 広告 ───
                        Section {
                            AdBannerView(adUnitID: "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX")
                                .listRowInsets(EdgeInsets())
                        }

                        // ─── 日記エントリー ───
                        Section("\(displayVisits.count)件の記録") {
                            ForEach(displayVisits) { visit in
                                NavigationLink {
                                    DiaryEntryDetailView(visit: visit)
                                } label: {
                                    DiaryRowView(visit: visit)
                                }
                            }
                            .onDelete { indexSet in
                                indexSet.forEach { viewModel.deleteVisit(displayVisits[$0]) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("温泉日記")
            .searchable(text: $searchText, prompt: "温泉名・メモで検索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("並び替え") {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    Label(order.rawValue,
                                          systemImage: sortOrder == order ? "checkmark" : "")
                                }
                            }
                        }
                        Section("評価フィルター") {
                            Button("すべて") { filterRating = nil }
                            ForEach(5...1, id: \.self) { r in
                                Button {
                                    filterRating = r
                                } label: {
                                    Label(String(repeating: "★", count: r),
                                          systemImage: filterRating == r ? "checkmark" : "")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

// MARK: - Stats Summary Card
struct StatsSummaryCard: View {
    @EnvironmentObject var viewModel: OnsenViewModel

    var body: some View {
        HStack(spacing: 0) {
            StatItem(value: "\(viewModel.uniqueVisitCount)", label: "訪問した温泉", icon: "mappin.circle.fill", color: .orange)
            Divider()
            StatItem(value: "\(viewModel.totalVisitCount)", label: "総入浴回数", icon: "drop.fill", color: .blue)
            Divider()
            StatItem(value: "\(viewModel.visitedPrefectures.count)", label: "都道府県", icon: "map.fill", color: .green)
        }
        .frame(height: 80)
        .background(Color(.systemBackground))
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Diary Row View
struct DiaryRowView: View {
    let visit: Visit

    var body: some View {
        HStack(spacing: 12) {
            // 日付
            VStack(spacing: 2) {
                Text(visit.date.formatted(.dateTime.month().day()))
                    .font(.headline)
                    .fontWeight(.bold)
                Text(visit.date.formatted(.dateTime.year()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44)
            .padding(6)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(visit.mood.icon)
                    Text(visit.onsenName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    if let weather = visit.weather {
                        Text(weather.icon)
                    }
                }

                StarRatingView(rating: visit.rating, size: 12)

                if !visit.notes.isEmpty {
                    Text(visit.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !visit.companions.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(visit.companions.joined(separator: "・"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Diary Entry Detail View
struct DiaryEntryDetailView: View {
    let visit: Visit
    @EnvironmentObject var viewModel: OnsenViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ─── ヘッダー ───
                VStack(alignment: .leading, spacing: 8) {
                    Text(visit.date.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(visit.onsenName)
                        .font(.title)
                        .fontWeight(.bold)

                    HStack {
                        StarRatingView(rating: visit.rating, size: 20, color: .yellow)
                        Text(visit.mood.icon + " " + visit.mood.rawValue)
                            .font(.subheadline)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // ─── 詳細情報 ───
                if visit.weather != nil || visit.soakDurationMinutes != nil {
                    HStack(spacing: 16) {
                        if let weather = visit.weather {
                            VStack(spacing: 4) {
                                Text(weather.icon).font(.title2)
                                Text(weather.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let duration = visit.soakDurationMinutes {
                            VStack(spacing: 4) {
                                Image(systemName: "timer").font(.title2).foregroundStyle(.blue)
                                Text("\(duration)分").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // ─── 同行者 ───
                if !visit.companions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("一緒に行った人", systemImage: "person.2.fill")
                            .font(.headline)
                        FlowLayout(items: visit.companions) { person in
                            Text(person)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                }

                // ─── メモ ───
                if !visit.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("メモ", systemImage: "note.text")
                            .font(.headline)
                        Text(visit.notes)
                            .font(.body)
                    }
                }

                // ─── 写真 ───
                if !visit.photoFileNames.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("写真", systemImage: "photo.fill")
                            .font(.headline)
                        PhotoGridView(fileNames: visit.photoFileNames)
                    }
                }

                // 広告
                AdRectangleView()
            }
            .padding()
        }
        .navigationTitle("日記")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        viewModel.deleteVisit(visit)
                        dismiss()
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

// MARK: - Flow Layout（タグ表示用）
struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        // iOS 16以降はViewThatFitsやGridを使うと綺麗だが
        // シンプルにHStackでラップする実装
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}

// MARK: - Photo Grid View
struct PhotoGridView: View {
    let fileNames: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
            ForEach(fileNames, id: \.self) { fileName in
                if let image = loadImage(fileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 100, minHeight: 100)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 100)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }
            }
        }
    }

    private func loadImage(_ fileName: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }
}

// MARK: - Empty Diary View
struct EmptyDiaryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(.orange.opacity(0.7))
            Text("まだ日記がありません")
                .font(.title3)
                .fontWeight(.semibold)
            Text("温泉に行ったら「行った！」ボタンで\n記録を残しましょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
