import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Enhanced Social Share View
/// 画像シェア・エクスポート・インポートを提供する友達共有ハブ
struct SocialShareView: View {
    @EnvironmentObject var viewModel: OnsenViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var renderedImage: UIImage? = nil
    @State private var showingExportSheet   = false
    @State private var showingImportPicker  = false
    @State private var importResult: String = ""
    @State private var showingImportAlert   = false
    @State private var exportFileURL: URL?  = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ─── 実績カード（プレビュー + 画像シェア） ───
                    VStack(alignment: .leading, spacing: 8) {
                        Label("実績カードをシェア", systemImage: "photo.fill")
                            .font(.headline)
                            .padding(.horizontal)

                        AchievementShareCard()
                            .padding(.horizontal)
                            .id(viewModel.uniqueVisitCount)  // 変更時に再レンダリング

                        HStack(spacing: 12) {
                            // テキストシェア
                            ShareLink(item: viewModel.shareText()) {
                                Label("テキスト", systemImage: "text.bubble")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            // 画像シェア
                            Button {
                                renderAndShare()
                            } label: {
                                Label("画像", systemImage: "photo")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.orange)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider().padding(.horizontal)

                    // ─── QR コード（プロフィール共有） ───
                    VStack(alignment: .leading, spacing: 8) {
                        Label("プロフィール QR コード", systemImage: "qrcode")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack {
                            Spacer()
                            if let qr = generateQRCode(from: viewModel.shareText()) {
                                Image(uiImage: qr)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 180, height: 180)
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 4)
                            }
                            Spacer()
                        }

                        Text("友達にスキャンしてもらうとあなたの実績が伝わります")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Divider().padding(.horizontal)

                    // ─── 訪問データ エクスポート / インポート ───
                    VStack(alignment: .leading, spacing: 12) {
                        Label("訪問記録の共有", systemImage: "arrow.up.arrow.down.circle")
                            .font(.headline)
                            .padding(.horizontal)

                        Text("訪問記録をファイルにエクスポートして友達に共有できます。友達のファイルをインポートして、どの温泉に行ったか確認しましょう。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            // エクスポート
                            Button {
                                exportVisits()
                            } label: {
                                Label("エクスポート", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                            }

                            // インポート
                            Button {
                                showingImportPicker = true
                            } label: {
                                Label("インポート", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // ─── 広告 ───
                    AdRectangleView()
                        .padding(.bottom)
                }
                .padding(.top)
            }
            .navigationTitle("友達とシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportFileURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("インポート結果", isPresented: $showingImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importResult)
            }
        }
    }

    // MARK: - Render Share Image
    @MainActor
    private func renderAndShare() {
        let card = AchievementShareCard()
            .environmentObject(viewModel)
            .frame(width: 360)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0

        guard let uiImage = renderer.uiImage else { return }

        let av = UIActivityViewController(activityItems: [uiImage], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root  = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    // MARK: - QR Code
    private func generateQRCode(from string: String) -> UIImage? {
        let context  = CIContext()
        let filter   = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Export Visits
    private func exportVisits() {
        let exportData = ExportData(
            userName:    viewModel.userName,
            titleName:   viewModel.currentTitle.name,
            visitCount:  viewModel.uniqueVisitCount,
            visits:      viewModel.visits,
            exportedAt:  Date()
        )
        guard let data = try? JSONEncoder().encode(exportData) else { return }

        let fileName = "OnsenMap_\(viewModel.userName)_\(Date().formatted(.dateTime.year().month().day())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        exportFileURL = url
        showingExportSheet = true
    }

    // MARK: - Import Visits
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importResult = "読み込みに失敗しました: \(error.localizedDescription)"
            showingImportAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data   = try Data(contentsOf: url)
                let export = try JSONDecoder().decode(ExportData.self, from: data)
                let newVisits = export.visits.filter { v in
                    !viewModel.visits.contains(where: { $0.id == v.id })
                }
                newVisits.forEach { viewModel.addVisit($0) }
                importResult = """
                「\(export.userName)」の記録をインポートしました。
                追加: \(newVisits.count)件
                (称号: \(export.titleName))
                """
            } catch {
                importResult = "ファイルの形式が正しくありません。"
            }
            showingImportAlert = true
        }
    }
}

// MARK: - Export Data Model
struct ExportData: Codable {
    let userName:   String
    let titleName:  String
    let visitCount: Int
    let visits:     [Visit]
    let exportedAt: Date
}

// MARK: - UIActivityViewController Wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
