import SwiftUI
import PhotosUI

// MARK: - Add Visit View（日記を書く）
struct AddVisitView: View {
    let onsen: Onsen
    @EnvironmentObject var viewModel: OnsenViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var rating = 3
    @State private var mood: Visit.Mood = .good
    @State private var weather: Visit.Weather? = nil
    @State private var notes = ""
    @State private var companionText = ""
    @State private var companions: [String] = []
    @State private var soakDuration: String = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhotos: [UIImage] = []

    var body: some View {
        NavigationStack {
            Form {
                // ─── 温泉名（読み取り専用） ───
                Section {
                    HStack {
                        Text(onsen.onsenType.icon)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(onsen.name)
                                .fontWeight(.bold)
                            Text(onsen.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // ─── 日時 ───
                Section("日時") {
                    DatePicker("入浴日", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                // ─── 評価 ───
                Section("評価") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("満足度")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(star <= rating ? .yellow : Color(.systemGray4))
                                    .onTapGesture { rating = star }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("気分")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ForEach(Visit.Mood.allCases, id: \.self) { m in
                                Button {
                                    mood = m
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(m.icon)
                                            .font(.title2)
                                        Text(m.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(mood == m ? .orange : .secondary)
                                    }
                                    .padding(8)
                                    .background(mood == m ? Color.orange.opacity(0.15) : Color.clear)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // ─── 天気 ───
                Section("天気") {
                    HStack(spacing: 12) {
                        Button {
                            weather = nil
                        } label: {
                            Text("未選択")
                                .font(.caption)
                                .foregroundStyle(weather == nil ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(weather == nil ? Color.gray : Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        ForEach(Visit.Weather.allCases, id: \.self) { w in
                            Button {
                                weather = w
                            } label: {
                                VStack(spacing: 2) {
                                    Text(w.icon)
                                    Text(w.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(weather == w ? .orange : .secondary)
                                }
                                .padding(8)
                                .background(weather == w ? Color.orange.opacity(0.15) : Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // ─── 入浴時間 ───
                Section("入浴時間（分）") {
                    TextField("例: 30", text: $soakDuration)
                        .keyboardType(.numberPad)
                }

                // ─── 同行者 ───
                Section("一緒に行った人") {
                    ForEach(companions, id: \.self) { person in
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                            Text(person)
                        }
                    }
                    .onDelete { companions.remove(atOffsets: $0) }

                    HStack {
                        TextField("名前を入力", text: $companionText)
                        Button {
                            if !companionText.trimmingCharacters(in: .whitespaces).isEmpty {
                                companions.append(companionText.trimmingCharacters(in: .whitespaces))
                                companionText = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // ─── メモ ───
                Section("日記・メモ") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .overlay(
                            Group {
                                if notes.isEmpty {
                                    Text("今日の温泉はどうでしたか？\n泉質、景色、食事など自由に記録しよう")
                                        .foregroundStyle(Color(.placeholderText))
                                        .allowsHitTesting(false)
                                        .padding(4)
                                }
                            },
                            alignment: .topLeading
                        )
                }

                // ─── 写真 ───
                Section("写真") {
                    PhotosPicker(selection: $selectedPhotoItems,
                                 maxSelectionCount: 5,
                                 matching: .images) {
                        Label("写真を選ぶ（最大5枚）", systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: selectedPhotoItems) { _, items in
                        Task {
                            selectedPhotos = []
                            for item in items {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data) {
                                    selectedPhotos.append(img)
                                }
                            }
                        }
                    }

                    if !selectedPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(selectedPhotos.enumerated()), id: \.offset) { _, img in
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .cornerRadius(8)
                                        .clipped()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("訪問を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { saveVisit() }
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Save
    private func saveVisit() {
        // 写真をドキュメントディレクトリに保存
        var fileNames: [String] = []
        for (index, image) in selectedPhotos.enumerated() {
            if let data = image.jpegData(compressionQuality: 0.7) {
                let fileName = "visit_\(UUID().uuidString)_\(index).jpg"
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(fileName)
                try? data.write(to: url)
                fileNames.append(fileName)
            }
        }

        let visit = Visit(
            onsenId: onsen.id,
            onsenName: onsen.name,
            date: date,
            notes: notes,
            rating: rating,
            mood: mood,
            companions: companions,
            weather: weather,
            soakDurationMinutes: Int(soakDuration),
            photoFileNames: fileNames
        )
        viewModel.addVisit(visit)
        dismiss()
    }
}
