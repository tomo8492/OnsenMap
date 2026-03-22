import Foundation
import SwiftUI

// MARK: - Title (称号)
struct Title: Identifiable {
    let id: Int
    let name: String          // 称号名
    let subtitle: String      // サブタイトル
    let requiredVisits: Int   // 必要な訪問数
    let icon: String          // SF Symbols name
    let color: Color
    let description: String

    /// タイトル一覧（訪問数昇順）
    static let all: [Title] = [
        Title(id: 0,  name: "未入浴者",      subtitle: "旅はこれから",            requiredVisits: 0,   icon: "figure.walk",              color: .gray,          description: "まだ温泉へ行っていません。最初の一湯へ！"),
        Title(id: 1,  name: "温泉初心者",    subtitle: "第一歩を踏み出した",       requiredVisits: 1,   icon: "drop.fill",                color: .blue,          description: "おめでとう！温泉デビューです！"),
        Title(id: 2,  name: "湯めぐりスタート", subtitle: "温泉の魅力に触れ始めた", requiredVisits: 5,   icon: "thermometer.medium",       color: .cyan,          description: "5か所達成！温泉の世界へようこそ。"),
        Title(id: 3,  name: "温泉ファン",    subtitle: "すっかりハマってきた",     requiredVisits: 10,  icon: "star.fill",                color: .yellow,        description: "10か所達成！本当の温泉好きになってきた。"),
        Title(id: 4,  name: "温泉通",        subtitle: "各地の湯を知る者",         requiredVisits: 20,  icon: "map.fill",                 color: .orange,        description: "20か所達成！温泉の奥深さが分かってきた。"),
        Title(id: 5,  name: "湯煙ハンター",  subtitle: "湯煙を追いかける旅人",     requiredVisits: 30,  icon: "cloud.fill",               color: .indigo,        description: "30か所達成！全国の名湯を渡り歩く旅人。"),
        Title(id: 6,  name: "温泉マニア",    subtitle: "温泉愛が止まらない",       requiredVisits: 50,  icon: "flame.fill",               color: .red,           description: "50か所達成！もはや温泉が人生の一部。"),
        Title(id: 7,  name: "湯匠",          subtitle: "湯の道を究めし者",         requiredVisits: 70,  icon: "crown.fill",               color: .purple,        description: "70か所達成！泉質や効能を語れる達人。"),
        Title(id: 8,  name: "温泉達人",      subtitle: "百湯を超えた探求者",       requiredVisits: 100, icon: "medal.fill",               color: Color(red: 0.8, green: 0.6, blue: 0.1), description: "100か所達成！温泉達人の称号を手に入れた！"),
        Title(id: 9,  name: "名湯探索者",    subtitle: "秘境の湯まで訪ねる",       requiredVisits: 150, icon: "binoculars.fill",           color: .green,         description: "150か所達成！日本中の名湯を巡る探索者。"),
        Title(id: 10, name: "温泉王",        subtitle: "日本の湯の王者",           requiredVisits: 200, icon: "crown.fill",               color: Color(red: 1.0, green: 0.84, blue: 0.0), description: "200か所達成！まさに温泉の王者！"),
        Title(id: 11, name: "大湯匠",        subtitle: "温泉文化の継承者",         requiredVisits: 300, icon: "sparkles",                 color: Color(red: 0.95, green: 0.5, blue: 0.9), description: "300か所達成！温泉文化を体現する大湯匠。"),
        Title(id: 12, name: "温泉の神様",    subtitle: "伝説の温泉巡礼者",         requiredVisits: 500, icon: "globe.asia.australia.fill", color: Color(red: 1.0, green: 0.6, blue: 0.0), description: "500か所達成！あなたはもはや温泉の神様だ！")
    ]

    /// 訪問数に応じた現在の称号を返す
    static func current(for visitCount: Int) -> Title {
        all.reversed().first { $0.requiredVisits <= visitCount } ?? all[0]
    }

    /// 次の称号を返す（最高位の場合はnil）
    static func next(after visitCount: Int) -> Title? {
        all.first { $0.requiredVisits > visitCount }
    }
}

// MARK: - Badge (バッジ)
struct Badge: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    var isUnlocked: Bool

    static let all: [Badge] = [
        Badge(id: "first_visit",      name: "初湯",         description: "はじめて温泉を記録した",             icon: "drop.fill",             color: .blue,   isUnlocked: false),
        Badge(id: "photo_debut",      name: "写真デビュー",  description: "はじめて写真を記録した",             icon: "camera.fill",            color: .purple, isUnlocked: false),
        Badge(id: "night_bath",       name: "夜の湯",        description: "夜間（20時以降）に入浴した",         icon: "moon.fill",              color: .indigo, isUnlocked: false),
        Badge(id: "snow_bath",        name: "雪見風呂",      description: "雪の日に入浴した",                   icon: "snowflake",              color: .cyan,   isUnlocked: false),
        Badge(id: "solo_trip",        name: "一人旅の湯",    description: "ひとりで入浴した",                   icon: "person.fill",            color: .gray,   isUnlocked: false),
        Badge(id: "group_trip",       name: "みんなで温泉",  description: "3人以上で入浴した",                  icon: "person.3.fill",          color: .green,  isUnlocked: false),
        Badge(id: "prefecture_3",     name: "3県制覇",       description: "3つの都道府県の温泉を巡った",         icon: "map.fill",               color: .orange, isUnlocked: false),
        Badge(id: "prefecture_10",    name: "10県制覇",      description: "10の都道府県の温泉を巡った",          icon: "globe.asia.australia.fill", color: .red, isUnlocked: false),
        Badge(id: "five_stars",       name: "五つ星の湯",    description: "5つ星の評価をつけた",                icon: "star.fill",              color: .yellow, isUnlocked: false),
        Badge(id: "weekly_visitor",   name: "週イチ常連",    description: "1週間以内に3回訪問した",             icon: "calendar.badge.clock",   color: .mint,   isUnlocked: false),
        Badge(id: "onsen_100",        name: "百湯達成",      description: "100か所の温泉を制覇した",            icon: "medal.fill",             color: Color(red: 0.8, green: 0.6, blue: 0.1), isUnlocked: false),
        Badge(id: "review_master",    name: "レビューマスター", description: "50件のノートを書いた",            icon: "pencil.and.outline",     color: .brown,  isUnlocked: false),
    ]
}
