# ♨️ OnsenMap - 温泉の日記マップ

日本中の温泉を記録・発見できるiPhoneアプリです。

## 機能一覧

| 機能 | 説明 |
|------|------|
| 🗺️ **温泉マップ** | MapKit を使って日本全国の温泉をピンで表示。訪問済み（オレンジ）と未訪問（ブルー）で色分け |
| 📖 **温泉日記** | 訪問日・評価・気分・天気・同行者・メモ・写真を記録できる日記機能 |
| 🏆 **称号システム** | 訪問数に応じて13段階の称号が解放。バッジコレクションも充実 |
| 👤 **プロフィール** | 統計・都道府県制覇マップ・設定 |
| 📢 **広告** | Google AdMob バナー広告（収益化） |
| 📤 **シェア** | 称号・記録を友達にシェア |

## 称号一覧

| 称号 | 必要訪問数 |
|------|-----------|
| 未入浴者 | 0か所 |
| 温泉初心者 | 1か所〜 |
| 湯めぐりスタート | 5か所〜 |
| 温泉ファン | 10か所〜 |
| 温泉通 | 20か所〜 |
| 湯煙ハンター | 30か所〜 |
| 温泉マニア | 50か所〜 |
| 湯匠 | 70か所〜 |
| 温泉達人 | 100か所〜 |
| 名湯探索者 | 150か所〜 |
| 温泉王 | 200か所〜 |
| 大湯匠 | 300か所〜 |
| 温泉の神様 | 500か所〜 |

---

## Xcode プロジェクトのセットアップ手順

### 必要な環境

- macOS 14 (Sonoma) 以降
- Xcode 15 以降
- iOS 17 以降の実機 or シミュレーター

### 手順

#### 1. Xcode プロジェクトを作成

1. Xcode を起動 → **Create New Project**
2. **iOS** タブ → **App** を選択
3. 設定:
   - **Product Name**: `OnsenMap`
   - **Team**: 自分のApple Developer アカウント
   - **Organization Identifier**: `com.yourcompany`
   - **Bundle Identifier**: `com.yourcompany.OnsenMap`
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
4. このリポジトリのクローン先と同じ場所にプロジェクトを作成

#### 2. ソースファイルを追加

Xcode プロジェクトに以下のファイルを追加します（Project Navigator で右クリック → Add Files）:

```
OnsenMap/
├── App/
│   └── OnsenMapApp.swift       ← @main エントリーポイント
├── ContentView.swift           ← メインタブビュー
├── Models/
│   ├── Onsen.swift
│   ├── Visit.swift
│   └── Achievement.swift
├── ViewModels/
│   └── OnsenViewModel.swift    ← LocationViewModel も含む
├── Views/
│   ├── Map/
│   │   ├── MapTabView.swift
│   │   └── OnsenDetailSheet.swift
│   ├── Diary/
│   │   ├── DiaryTabView.swift
│   │   └── AddVisitView.swift
│   ├── Achievement/
│   │   └── AchievementsTabView.swift
│   ├── Profile/
│   │   └── ProfileTabView.swift
│   └── Common/
│       ├── AdBannerView.swift
│       └── StarRatingView.swift
└── Services/
    ├── PersistenceService.swift
    └── SampleData.swift
```

> **注意**: Xcode のテンプレートで生成された `ContentView.swift` と `AppName.swift` は削除して、このリポジトリのファイルに置き換えてください。

#### 3. Info.plist の設定

`Resources/Info.plist` の内容を参考に、Xcode プロジェクトの Info.plist（または Target → Info タブ）に以下のキーを追加:

| Key | Value |
|-----|-------|
| `NSLocationWhenInUseUsageDescription` | 近くの温泉を地図に表示するために現在地を使用します。 |
| `NSCameraUsageDescription` | 温泉の写真を撮影して日記に記録します。 |
| `NSPhotoLibraryUsageDescription` | 温泉の写真を日記に追加します。 |
| `LSApplicationQueriesSchemes` | `comgooglemaps`, `maps` |

#### 4. Assets の設定

- Xcode の `Assets.xcassets` でアクセントカラーをオレンジ (`#FF8000`) に設定
- アプリアイコンを `AppIcon` に追加（1024×1024px の PNG）

---

## iCloud 同期の設定（CloudKit）

訪問記録・日記・バッジ・カスタム温泉・プロフィール名は **iCloud Private Database** に同期されます。
ユーザーの iCloud 容量を消費するため、開発者側のサーバー費用は **¥0** です。

### Xcode Capabilities の有効化

1. Xcode → Target `OnsenMap` → **Signing & Capabilities** タブを開く
2. **+ Capability** から **iCloud** を追加
3. 以下を有効化:
   - ✅ **CloudKit**
   - Containers: `iCloud.com.yourcompany.OnsenMap`（Bundle ID と揃える）
4. **+ Capability** から **Background Modes** を追加し、`Remote notifications` をオン（任意・将来のプッシュ同期用）

### CloudKit Dashboard でスキーマ確認

初回ビルド・実機テスト時に下記レコードタイプが自動生成されます。
[CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/) で確認してください。

| Record Type | フィールド | 用途 |
|---|---|---|
| `Visit` | id, onsenId, onsenName, date, notes, rating, mood, companions, weather, soakDurationMinutes, photoFileNames | 日記エントリー |
| `VisitedOnsen` | onsenId | 訪問済み温泉ID |
| `UnlockedBadge` | badgeId | 解放済みバッジ |
| `CustomOnsen` | id, name, latitude, longitude ほか | ユーザー追加温泉 |
| `UserProfile` | userName | ニックネーム（単一レコード `userProfile`） |

> **注意**: 開発環境（Development）でテストした後、リリース前に **Deploy Schema to Production** を実行してください。

### 同期挙動

- **起動時 / フォアグラウンド復帰時**: iCloud から pull → ローカルとユニオンマージ
- **記録の追加・編集・削除**: ローカル即時保存 + バックグラウンドで CloudKit にプッシュ
- **iCloud 未ログイン**: ローカルのみで動作（プロフィール画面に「iCloud未ログイン」表示）
- **オフライン**: ローカル動作のみ。次回オンライン時に再同期

### 既知の制限（v1.0）

- 写真のピクセルデータは未同期（`photoFileNames` のみ同期）。CKAsset 対応は今後の TODO
- 競合解決は「最後の書き込み勝ち」（CKModifyRecordsOperation の `.changedKeys` policy）

---

## OnsenMap Pro（StoreKit 2 IAP）

Pro 機能（広告非表示・写真無制限・CSVエクスポート）を **買い切り ¥980** で提供します。

### App Store Connect 側の設定

1. App Store Connect → アプリ → **App内課金** → **+** で新規作成
2. **タイプ**: 「非消耗型」
3. **製品ID**: `com.yourcompany.OnsenMap.lifetime_pro`（`Services/StoreManager.swift` の `ProductID.lifetimePro` と一致させる）
4. **参照名**: `Lifetime Pro`
5. 価格: ¥980（または好きな価格）
6. ローカライゼーション（日本語）:
   - 表示名: `OnsenMap Pro`
   - 説明: `OnsenMap のすべての特典を一度の購入で永続的に利用できます。広告非表示・写真無制限・CSVエクスポート・詳細統計などが含まれます。`

### Xcode のローカルテスト設定

実機・実 Apple ID で課金することなく、StoreKit Configuration ファイルでローカルテストできます。

1. `OnsenMap/Resources/Configuration.storekit` を Xcode の Project Navigator にドラッグ
2. Edit Scheme → **Run** → **Options** タブ → **StoreKit Configuration** で `Configuration.storekit` を選択
3. ビルド & 実行 → プロフィール → 「OnsenMap Pro」をタップ → 課金フローをローカルで試せる
4. Xcode メニュー → Debug → StoreKit → Manage Transactions で購入リセット可能

### 動作確認チェックリスト

- [ ] Pro未購入: バナー広告が表示される
- [ ] Pro購入後: バナー広告が `EmptyView()` で非表示になる
- [ ] Pro購入後: 写真選択枚数が無制限 (`maxSelectionCount: 0`)
- [ ] Pro購入後: 「データ管理」→「CSVエクスポート」が有効化される
- [ ] アプリ削除→再インストール後、「購入を復元」で `purchasedProductIDs` が復元される

---

## AdMob インタースティシャル（称号アップグレード時）

`Services/InterstitialAdManager.swift` で、称号がアップグレードされた瞬間にインタースティシャル広告を表示します。

- 起動時に `preload()` で広告をロード
- `OnsenViewModel.addVisit()` 内で title.id の差分検知 → `showIfReady()`
- 連続表示防止: 同一セッション内で 90 秒以上の間隔
- Pro ユーザーには絶対に表示しない (`StoreManager.shared.isPro` チェック)

### テスト用 ID（DEBUG ビルド）

`ca-app-pub-3940256099942544/4411468910`（Google公式テスト広告）

### 本番用 ID

`Services/InterstitialAdManager.swift` の `productionAdUnitID` を AdMob で発行した本番 ID に書き換えてください。

### GoogleMobileAds SDK の組み込み

```
File → Add Package Dependencies →
URL: https://github.com/googleads/swift-package-manager-google-mobile-ads
```

SDK が組み込まれると `#if canImport(GoogleMobileAds)` ブロックが有効になり、自動でインタースティシャル機能が動き出します。

---

## 楽天トラベル アフィリエイトの設定（送客収益化）

温泉の詳細画面から「近くの宿を探す」セクションで楽天トラベル経由の宿予約に送客し、
**1予約あたり ¥200〜500 程度の成果報酬** を得られます。広告より ROI が高い旅行アプリの定石です。

### 1. 楽天 Application ID を取得

1. [楽天デベロッパーズ](https://webservice.rakuten.co.jp/app/create) でアプリ登録
2. アプリケーション ID（19桁の数字）が発行される

### 2. 楽天アフィリエイト ID を取得

1. [楽天アフィリエイト](https://affiliate.rakuten.co.jp/) でアカウント登録（無料）
2. マイページ → 「ID確認」でアフィリエイト ID を取得（形式: `12345678.abcd1234.efgh5678`）

### 3. アプリに ID を設定

`OnsenMap/Services/RakutenTravelService.swift` の `AffiliateConfig` を編集:

```swift
enum AffiliateConfig {
    static let rakutenApplicationId: String? = "1234567890123456789"           // ← 取得した値
    static let rakutenAffiliateId:   String? = "12345678.abcd1234.efgh5678"    // ← 取得した値
}
```

### 4. 動作確認

- ID 未設定時: 「楽天トラベルで○○を探す」フォールバックボタンが表示される（アフィリエイト ID があれば成果計上される）
- ID 設定後: 温泉詳細画面で「近くの宿を探す」をタップ → 半径3km 以内の宿リストが表示される

### 5. 注意事項

- 楽天トラベル API は1秒1回程度のレート制限があります
- アフィリエイトリンクの有効期間は30日（クッキー）
- App Store の審査では特に問題になりません（外部 Web ブラウザに遷移するため）

---

## じゃらん net アフィリエイトの設定（楽天と並列）

`Services/JalanTravelService.swift` 経由でじゃらん net への送客 URL を組み立てます。
v1 では API でのインライン一覧は未対応（XML応答のため）ですが、検索URLでの送客で同等のアフィリエイト報酬が得られます。

### ValueCommerce LinkSwitch を使う場合

1. [ValueCommerce](https://affiliate.valuecommerce.ne.jp/) でアフィリエイト登録
2. じゃらん net プログラムに参加（審査あり）
3. 広告タグの `sid` `pid` を取得（例: `sid=3000000&pid=880000000`）
4. `Services/JalanTravelService.swift` の `AffiliateConfig.valueCommerceJalanQuery` に値を設定

### リクルートWebサービス API を使う場合（v2 検討）

XMLパーサー実装が必要なため v1 では非対応。`AffiliateConfig.jalanApiKey` に取得した API キーを保存しておくと、v2 アップデートで自動有効化されます。

---

## Google AdMob の設定（広告収益化）

### AdMob アカウントの作成

1. [Google AdMob](https://admob.google.com/) でアカウントを作成
2. **アプリを追加** → iOS → アプリ名: `OnsenMap`
3. **App ID** をコピー（例: `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`）

### SDK のインストール

**Swift Package Manager** を使用:

1. Xcode → **File** → **Add Package Dependencies**
2. URL を入力: `https://github.com/googleads/swift-package-manager-google-mobile-ads`
3. **Add Package** をクリック

### Info.plist に App ID を追加

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>
```

### SDK の初期化とバナー有効化

`OnsenMapApp.swift` のコメントアウトを外す:

```swift
import GoogleMobileAds

init() {
    GADMobileAds.sharedInstance().start(completionHandler: nil)
}
```

`AdBannerView.swift` のコメントアウトを外す:

```swift
import GoogleMobileAds

// プレースホルダーを本物のバナーに変更
struct AdBannerView: View {
    let adUnitID: String
    var body: some View {
        GADBannerViewRepresentable(adUnitID: adUnitID)
    }
}
```

各 `AdBannerView` の `adUnitID` を実際の広告ユニット ID に変更:

```swift
// テスト用（開発中）
AdBannerView(adUnitID: "ca-app-pub-3940256099942544/2934735716")

// 本番用（リリース時に変更）
AdBannerView(adUnitID: "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX")
```

---

## 温泉データについて

初期データとして全国の代表的な温泉 25 か所以上を収録しています。

さらに多くの温泉データを追加したい場合:
- [e-Stat 公衆浴場データ](https://www.e-stat.go.jp/stat-search/database?page=1&query=公衆浴場&layout=dataset) を活用
- `SampleData.swift` の `onsens` 配列に追加

マップ上で周辺温泉を検索する機能（MapKit Local Search）も搭載しています。

---

## ファイル構成

```
OnsenMap/
├── App/
│   └── OnsenMapApp.swift       # アプリエントリーポイント
├── ContentView.swift            # メインタブビュー
├── Models/
│   ├── Onsen.swift              # 温泉データモデル
│   ├── Visit.swift              # 訪問（日記）モデル
│   └── Achievement.swift        # 称号・バッジモデル
├── ViewModels/
│   └── OnsenViewModel.swift     # メインVM + LocationViewModel
├── Views/
│   ├── Map/
│   │   ├── MapTabView.swift     # マップ画面
│   │   └── OnsenDetailSheet.swift # 温泉詳細シート
│   ├── Diary/
│   │   ├── DiaryTabView.swift   # 日記一覧
│   │   └── AddVisitView.swift   # 訪問記録追加
│   ├── Achievement/
│   │   └── AchievementsTabView.swift # 称号・バッジ画面
│   ├── Profile/
│   │   └── ProfileTabView.swift # プロフィール画面
│   └── Common/
│       ├── AdBannerView.swift   # 広告バナー
│       └── StarRatingView.swift # 星評価コンポーネント
├── Services/
│   ├── PersistenceService.swift # データ永続化（UserDefaults）
│   └── SampleData.swift         # サンプル温泉データ
└── Resources/
    ├── Info.plist               # アプリ設定
    └── Assets.xcassets/         # 画像・カラーアセット
```

---

## 技術スタック

- **Swift 5.9** / **SwiftUI**
- **MapKit** - 地図表示・周辺検索
- **CoreLocation** - 位置情報
- **PhotosUI** - 写真ピッカー
- **UserDefaults + Codable** - ローカルキャッシュ
- **CloudKit** - iCloud Private Database 同期（記録・日記・バッジ・カスタム温泉）
- **Google Mobile Ads SDK** - 広告収益化（要別途インストール）

## ライセンス

MIT License
