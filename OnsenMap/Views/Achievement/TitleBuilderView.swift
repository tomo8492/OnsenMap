import SwiftUI

// MARK: - Title Builder View（称号カスタマイズ）
/// 「宮城の温泉仙人」のようなオリジナル称号を作れる画面
struct TitleBuilderView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @Environment(\.dismiss) private var dismiss

    // 組み合わせパーツ
    @State private var selectedPrefix: PrefixOption
    @State private var customPrefixText: String = ""
    @State private var selectedSuffix: SuffixOption
    @State private var customSuffixText: String = ""

    // プレビュー更新用
    @State private var previewScale: CGFloat = 1.0

    init(viewModel: OnsenViewModel) {
        // 最多訪問都道府県を初期値に
        let topPref = viewModel.visitedPrefectures
            .map { pref in (pref, viewModel.visitedOnsens.filter { $0.prefecture == pref }.count) }
            .max(by: { $0.1 < $1.1 })?.0

        _selectedPrefix = State(initialValue: topPref.map { .prefecture($0) } ?? .none)
        _selectedSuffix = State(initialValue: .earned)
    }

    // MARK: - Prefix Options
    enum PrefixOption: Hashable {
        case none
        case prefecture(String)
        case custom

        var label: String {
            switch self {
            case .none:             return "なし"
            case .prefecture(let p): return "\(p)の"
            case .custom:           return "カスタム"
            }
        }
    }

    // MARK: - Suffix Options
    enum SuffixOption: Hashable {
        case earned                 // 獲得した称号
        case unlockedTitle(Int)     // 他の解放済み称号
        case creative(String)       // 創作称号
        case custom                 // 自由入力

        var label: String {
            switch self {
            case .earned:                return "現在の称号"
            case .unlockedTitle(let id): return Title.all.first { $0.id == id }?.name ?? ""
            case .creative(let name):    return name
            case .custom:               return "自由入力"
            }
        }
    }

    // 창作称号リスト（訪問数に応じて解放）
    var creativeOptions: [(name: String, requiredVisits: Int)] {
        [
            ("仙人",   20),
            ("達者",   15),
            ("旅人",    1),
            ("探検家", 10),
            ("王者",   50),
            ("伝説",  100),
            ("神話",  200),
            ("幻想家",  5),
            ("侠客",   30),
            ("隠者",   20),
            ("巡礼者", 10),
            ("守護者", 70),
        ]
    }

    // 解放済み称号（現在の称号含む）
    var unlockedTitles: [Title] {
        Title.all.filter { viewModel.uniqueVisitCount >= $0.requiredVisits }
    }

    // MARK: - Computed Full Title
    var builtTitle: String {
        let prefix: String = {
            switch selectedPrefix {
            case .none:              return ""
            case .prefecture(let p): return "\(p)の"
            case .custom:            return customPrefixText.isEmpty ? "" : customPrefixText
            }
        }()

        let suffix: String = {
            switch selectedSuffix {
            case .earned:                return viewModel.currentTitle.name
            case .unlockedTitle(let id): return Title.all.first { $0.id == id }?.name ?? ""
            case .creative(let name):    return name
            case .custom:                return customSuffixText.isEmpty ? "温泉家" : customSuffixText
            }
        }()

        return prefix + suffix
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ─── プレビューカード ───
                    TitlePreviewCard(title: builtTitle, viewModel: viewModel)
                        .scaleEffect(previewScale)
                        .animation(.spring(response: 0.3), value: builtTitle)
                        .padding(.horizontal)
                        .onChange(of: builtTitle) { _, _ in
                            withAnimation(.easeInOut(duration: 0.1)) { previewScale = 1.05 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.1)) { previewScale = 1.0 }
                            }
                        }

                    // ─── PART 1: 場所の接頭語 ───
                    VStack(alignment: .leading, spacing: 12) {
                        Label("① 場所（前半）", systemImage: "mappin.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        // なし
                        PrefixChip(
                            label: "なし",
                            isSelected: selectedPrefix == .none
                        ) { selectedPrefix = .none }

                        // 訪問した都道府県
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                            ForEach(Array(viewModel.visitedPrefectures).sorted(), id: \.self) { pref in
                                PrefixChip(
                                    label: "\(pref)の",
                                    isSelected: selectedPrefix == .prefecture(pref)
                                ) { selectedPrefix = .prefecture(pref) }
                            }
                        }

                        // カスタム
                        PrefixChip(label: "✏️ 自由入力", isSelected: selectedPrefix == .custom) {
                            selectedPrefix = .custom
                        }
                        if selectedPrefix == .custom {
                            TextField("例: 東北の、山の", text: $customPrefixText)
                                .textFieldStyle(.roundedBorder)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .padding(.horizontal)

                    // ─── PART 2: 称号の後半 ───
                    VStack(alignment: .leading, spacing: 12) {
                        Label("② 称号（後半）", systemImage: "crown.fill")
                            .font(.headline)
                            .foregroundStyle(.purple)

                        // 現在の称号
                        SuffixChip(
                            label: "現在の称号「\(viewModel.currentTitle.name)」",
                            color: viewModel.currentTitle.color,
                            isSelected: selectedSuffix == .earned
                        ) { selectedSuffix = .earned }

                        // 解放済み称号
                        if unlockedTitles.count > 1 {
                            Text("解放済みの称号")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                                ForEach(unlockedTitles.filter { $0.id != viewModel.currentTitle.id }) { title in
                                    SuffixChip(
                                        label: title.name,
                                        color: title.color,
                                        isSelected: selectedSuffix == .unlockedTitle(title.id)
                                    ) { selectedSuffix = .unlockedTitle(title.id) }
                                }
                            }
                        }

                        // 創作称号
                        Text("創作称号（訪問数で解放）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                            ForEach(creativeOptions.filter { viewModel.uniqueVisitCount >= $0.requiredVisits }, id: \.name) { opt in
                                SuffixChip(
                                    label: opt.name,
                                    color: .indigo,
                                    isSelected: selectedSuffix == .creative(opt.name)
                                ) { selectedSuffix = .creative(opt.name) }
                            }
                        }
                        if creativeOptions.contains(where: { viewModel.uniqueVisitCount < $0.requiredVisits }) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("訪問数が増えると更多くの称号が解放されます")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 完全自由入力
                        SuffixChip(label: "✏️ 自由入力", color: .gray, isSelected: selectedSuffix == .custom) {
                            selectedSuffix = .custom
                        }
                        if selectedSuffix == .custom {
                            TextField("例: 温泉仙人、湯の番人", text: $customSuffixText)
                                .textFieldStyle(.roundedBorder)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .padding(.horizontal)

                    // 広告
                    AdRectangleView()
                        .padding(.bottom)
                }
                .padding(.top)
            }
            .navigationTitle("称号をカスタマイズ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("この称号に決定！") {
                        viewModel.setCustomDisplayTitle(builtTitle)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - Title Preview Card
struct TitlePreviewCard: View {
    let title: String
    let viewModel: OnsenViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("プレビュー")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [viewModel.currentTitle.color.opacity(0.2),
                                     viewModel.currentTitle.color.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Image(systemName: viewModel.currentTitle.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(viewModel.currentTitle.color)

                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(viewModel.currentTitle.color)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)

                    Text("\(viewModel.userName) • \(viewModel.uniqueVisitCount)か所制覇")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .frame(height: 160)
        }
    }
}

// MARK: - Chip Components
struct PrefixChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.orange : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

struct SuffixChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
