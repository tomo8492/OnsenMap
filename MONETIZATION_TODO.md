# 💰 OnsenMap 収益化 TODO

評価会話（2026-04-30）と CloudKit 同期実装を踏まえた、収益化までの作業ログ。

---

## 🟢 完了

- [x] **CloudKit 同期の実装**（2026-04-30）
  - `CloudKitSyncService.swift` 新規追加
  - 訪問記録・日記・バッジ・カスタム温泉・プロフィール名を iCloud Private DB に同期
  - 起動時 / フォアグラウンド復帰時に自動 pull→マージ、各 mutation で incremental push
  - プロフィール画面に同期ステータス UI 追加
  - **Pro プランの中核機能（クラウド同期）の土台が完成 → 課金理由が立てられるように**

- [x] **楽天トラベル アフィリエイト導入**（2026-04-30）
  - `RakutenTravelService.swift` + `AffiliateConfig` 新規追加
  - 温泉詳細画面に「近くの宿を探す」セクションを追加（半径3km以内の宿リスト）
  - 楽天 SimpleHotelSearch API でホテル検索、評価・最低料金・サムネイル表示
  - `affiliateId` パラメータ付与でクリック→予約の成果報酬を計上
  - API 未設定時はフォールバックの楽天トラベル検索URL（アフィリエイトラップ済み）
  - **広告より ROI の高い送客収益のチャネルが開通**
  - 残: 楽天デベロッパーで Application ID + アフィリエイト ID を取得して `AffiliateConfig` に設定する

---

## 🔴 リリース前ブロッカー（App Store 審査で弾かれる）

- [ ] **プライバシーポリシー / 利用規約の URL を実値に**
  - `Views/Profile/ProfileTabView.swift:106-110` の `https://example.com/...` を本番 URL に
  - GitHub Pages / Notion 公開ページで簡易ページ用意でOK
- [ ] **App Store レビュー URL の実 App ID 化**
  - `Views/Profile/ProfileTabView.swift:144` の `idYOUR_APP_ID` を実値に
- [ ] **AdMob の本番 App ID / 広告ユニット ID を Info.plist & コードに反映**
  - `Views/Map/MapTabView.swift:104` `Views/Profile/ProfileTabView.swift:86` の `ca-app-pub-XXXXX...`
- [ ] **AdMob SDK の実組み込み**
  - `Views/Common/AdBannerView.swift:13, 49-65` のコメントアウトを外す
  - `App/OnsenMapApp.swift` の `GADMobileAds.sharedInstance().start(...)` を有効化
- [ ] **iCloud Capability の有効化**
  - Xcode Target Capabilities で iCloud + CloudKit Container 設定（README参照）
  - CloudKit Dashboard で Schema を Production にデプロイ

---

## 🟡 収益化施策（優先度順）

### ★★★ 必須 — 旅行アプリで最も ROI が高い

- [x] **楽天トラベル アフィリエイト導入** ← 完了（コード側）
  - `Services/RakutenTravelService.swift` 実装済み
  - `Views/Map/OnsenDetailSheet.swift` に `NearbyHotelsSection` を組み込み済み
  - **要対応**: 楽天デベロッパーで Application ID + アフィリエイト ID を取得して `AffiliateConfig` に設定
- [ ] **じゃらん net Webサービス対応**（楽天と並列で提示してCTRを底上げ）
  - リクルート Webサービス API の利用申請
  - `JalanTravelService.swift` を同パターンで実装し、`NearbyHotelsSection` にタブ表示
- [ ] **Booking.com / agoda アフィリエイト**（インバウンド対応・将来）

### ★★★ Pro プラン（買い切り or サブスク）

- [ ] **StoreKit 2 で IAP 実装**
  - 候補A: 買い切り「OnsenMap Pro」¥980 一回
  - 候補B: サブスク ¥300/月 or ¥2,400/年
  - 個人開発・温泉ニッチ では **買い切りの方が抵抗感が少なく回収しやすい** 想定
- [ ] **Pro 限定機能の実装**
  - [x] iCloud 同期（無料でも提供する方が UX 良い → Pro特典から外してもOK）
  - [ ] 広告非表示（最も訴求しやすい特典）
  - [ ] 写真5枚制限 → 無制限
  - [ ] CSV / PDF エクスポート
  - [ ] 詳細統計（年別・月別の訪問グラフなど）
  - [ ] アプリアイコン変更
- [ ] **Pro 課金モデルの判断ポイント**
  - クラウド同期を「Pro限定」にするか「無料機能」にするか要検討
  - 無料化推奨 → ユーザー定着率↑ → 広告 + アフィリエイト収益で回収

### ★★ 広告（ベースライン）

- [ ] **AdMob リワード広告 / インタースティシャル追加**
  - 称号解放時にお祝いインタースティシャル → eCPM が高い
  - リワード広告で「この月は広告非表示」を提供（ハイブリッド型）
- [ ] **メディエーション設定**（AdMob + UnityAds + AppLovin で eCPM 最適化）

### ★ 中長期施策

- [ ] **温泉ソムリエ監修コラム**（Pro 限定コンテンツ）
- [ ] **旅館・日帰り温泉の有料スポンサー枠**
  - 「PR」表示付きで上位掲載
  - 個別契約ベース、月 ¥5,000〜
- [ ] **ユーザーレビュー・写真 UGC 機能**（CloudKit Public DB 利用）
  - エンゲージメント↑ → 広告露出↑
- [ ] **プッシュ通知**（Background Modes Remote notifications を活用）
  - 「最後の入浴から30日経過」リマインダー → リテンション向上

---

## 🛠️ 技術的フォローアップ（収益化に直結する改善）

- [ ] **写真の CloudKit CKAsset 同期**
  - 現状は `photoFileNames` のみ同期。実画像は端末ローカル
  - `Documents/visit_*.jpg` を `CKAsset` で添付して機種変対応
- [ ] **CloudKit プッシュ通知購読**（`CKQuerySubscription`）で多端末リアルタイム同期
- [ ] **オフラインキューイング**: iCloud 未ログイン時 / ネットワーク失敗時の push を再試行
- [ ] **CloudKit エラーの可視化** — 現状は `print` のみ。`@Published var lastError` など追加
- [ ] **データエクスポート機能** — JSON / CSV ダウンロード（Pro特典 + 安心材料）

---

## 📊 想定収益感（個人開発・日本ローカル）

| ステージ | MAU | 主収益源 | 月間想定 |
|---|---|---|---|
| ローンチ初期 | 〜1,000 | AdMob のみ | ¥1,000〜¥5,000 |
| 成長期 | 1万〜3万 | AdMob + アフィリエイト | ¥30,000〜¥100,000 |
| 安定期 | 3万〜10万 | + Pro IAP（3〜5%課金率） | ¥100,000〜¥500,000 |

**鍵**: アフィリエイト導線 を最優先で入れる。広告だけでは伸びない。

---

## 📅 推奨ロードマップ

### Phase 1（リリースMVP・2週間）
1. 上記「リリース前ブロッカー」全部潰す
2. AdMob バナー有効化
3. App Store 審査提出

### Phase 2（収益化v1・1ヶ月）
1. 楽天トラベル アフィリエイト導入
2. インタースティシャル広告追加（称号解放時）
3. レビュー誘導 SKStoreReviewController を 5訪問達成時に表示

### Phase 3（Pro化・1〜2ヶ月）
1. StoreKit 2 で買い切り Pro 実装
2. 広告非表示 + CSV/PDFエクスポート + 詳細統計
3. 写真の CKAsset 同期

### Phase 4（成長施策）
1. UGC（公開レビュー）
2. プッシュ通知でリテンション
3. ユニバーサルリンクで宿サイトへの送客最適化
