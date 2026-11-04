import Foundation

struct Item { let id, name, rarity, use: String }
struct Course { let minutes, rest: Int; let title: String; let loot: Int; let rare, ring: Double; var coin = 0.0; var hidden = 0.0; var need: String? = nil }
struct Cosmetic { let id, name, currency: String; let price: Int }
struct Mile { let count: Int; let isHat: Bool; let value, name: String }
struct Genre { let id, name, hat, hatName, title, mark: String }
struct Food { let id, name, note: String; let price: Int }
struct ShopItem { let id, name: String; let price: Int; let deco: String? }
struct ItemSet { let id, name: String; let items: [String]; let note: String }
struct Medal { let id, name: String; let coins: Int; let done: (GameState) -> Bool }
struct Bond { let min: Double; let name, note: String }

enum Catalog {
    static let items = [
        Item(id: "stone", name: "작은 돌멩이", rarity: "일반", use: "수집"),
        Item(id: "twig", name: "나뭇가지", rarity: "일반", use: "둥지 재료"),
        Item(id: "feather", name: "깃털", rarity: "일반", use: "둥지 장식"),
        Item(id: "cap", name: "병뚜껑", rarity: "일반", use: "수집"),
        Item(id: "button", name: "단추", rarity: "희귀", use: "둥지 장식"),
        Item(id: "key", name: "열쇠", rarity: "희귀", use: "숨겨진 골짜기 열기"),
        Item(id: "coin", name: "동전", rarity: "희귀", use: "상점에서 사용"),
        Item(id: "ring", name: "반지", rarity: "전설", use: "특별 진화"),
        Item(id: "bone", name: "오래된 뼈", rarity: "골짜기", use: "세트 수집"),
        Item(id: "seed", name: "고대 씨앗", rarity: "골짜기", use: "세트 수집"),
        Item(id: "grain", name: "황금 곡물", rarity: "골짜기", use: "세트 수집")
    ]
    static let common = ["stone", "twig", "feather", "cap"]
    static let rare = ["button", "key", "coin"]
    static let hidden = ["bone", "seed", "grain"]
    static let courses = [
        Course(minutes: 30, rest: 5, title: "둥지 근처", loot: 1, rare: 0.10, ring: 0),
        Course(minutes: 50, rest: 10, title: "숲 탐험", loot: 2, rare: 0.28, ring: 0.01),
        Course(minutes: 180, rest: 15, title: "깊은 숲", loot: 4, rare: 0.35, ring: 0.02),
        Course(minutes: 360, rest: 20, title: "강가", loot: 6, rare: 0.3, ring: 0.02, coin: 0.4, need: "river"),
        Course(minutes: 540, rest: 30, title: "먼 산", loot: 8, rare: 0.44, ring: 0.05),
        Course(minutes: 720, rest: 30, title: "숨겨진 골짜기로 떠나는 여행", loot: 10, rare: 0.35, ring: 0.06, hidden: 0.5, need: "valley")
    ]
    static let cosmetics = [
        Cosmetic(id: "ribbon", name: "리본", currency: "acorn", price: 10),
        Cosmetic(id: "flower", name: "꽃 장식", currency: "acorn", price: 12),
        Cosmetic(id: "straw", name: "밀짚모자", currency: "acorn", price: 20),
        Cosmetic(id: "wreath", name: "화환", currency: "gem", price: 3),
        Cosmetic(id: "crown", name: "왕관", currency: "gem", price: 5),
        Cosmetic(id: "aura", name: "반짝 오라", currency: "gem", price: 8)
    ]
    static let miles: [String: [Mile]] = [
        "explore": [Mile(count: 3, isHat: true, value: "explorer", name: "탐험 모자"), Mile(count: 10, isHat: true, value: "goggles", name: "탐험 고글"), Mile(count: 20, isHat: false, value: "탐험가", name: "호칭 탐험가")],
        "read": [Mile(count: 3, isHat: true, value: "glasses", name: "둥근 안경"), Mile(count: 10, isHat: true, value: "mortar", name: "학사모"), Mile(count: 20, isHat: false, value: "책벌레", name: "호칭 책벌레")],
        "walk": [Mile(count: 3, isHat: true, value: "headband", name: "운동 머리띠"), Mile(count: 10, isHat: true, value: "sunhat", name: "나들이 모자"), Mile(count: 20, isHat: false, value: "산책 친구", name: "호칭 산책 친구")]
    ]
    static let actNames = ["explore": "탐험", "read": "책읽기", "walk": "산책"]
    static let genres = [
        Genre(id: "romance", name: "로맨스", hat: "hairpin", hatName: "하트 머리핀", title: "낭만 까마귀", mark: "crow/st_heart"),
        Genre(id: "scifi", name: "공상과학", hat: "antenna", hatName: "우주 안테나", title: "우주 까마귀", mark: "crow/st_spark"),
        Genre(id: "philosophy", name: "철학", hat: "laurel", hatName: "월계관", title: "사색가", mark: "bubbles/question"),
        Genre(id: "poetry", name: "시", hat: "quill", hatName: "깃펜 장식", title: "시인", mark: ""),
        Genre(id: "essay", name: "에세이", hat: "beret", hatName: "베레모", title: "수필가", mark: "crow/st_z"),
        Genre(id: "mystery", name: "추리", hat: "detective", hatName: "탐정 모자", title: "명탐정", mark: "bubbles/bang")
    ]
    static let foods = [
        Food(id: "berry", name: "산딸기", note: "건강식 · 배부름 +15", price: 2),
        Food(id: "seed", name: "씨앗", note: "간식 · 기분·체력 +10", price: 2),
        Food(id: "grain", name: "곡물", note: "식사 · 배부름 +25", price: 3),
        Food(id: "bread", name: "빵 조각", note: "간식 · 기분 +15", price: 3),
        Food(id: "fish", name: "생선뼈", note: "특식 · 배부름 +40", price: 5)
    ]
    static let shop = [
        ShopItem(id: "deco_flower", name: "꽃 장식", price: 2, deco: "flower"),
        ShopItem(id: "deco_mush", name: "버섯 장식", price: 2, deco: "mush"),
        ShopItem(id: "deco_grass", name: "풀 장식", price: 2, deco: "grass"),
        ShopItem(id: "river", name: "강가 지도", price: 4, deco: nil)
    ]
    static let sets = [
        ItemSet(id: "common", name: "둥지 근처 세트", items: common, note: "가끔 물건을 보며 기뻐해요"),
        ItemSet(id: "rare", name: "반짝이 세트", items: rare, note: "날개를 펼쳐요"),
        ItemSet(id: "valley", name: "골짜기 세트", items: hidden, note: "몸에서 반짝임이 나요")
    ]
    static let medals = [
        Medal(id: "w20", name: "지렁이 20점", coins: 1) { $0.bestWorm >= 20 },
        Medal(id: "w40", name: "지렁이 40점", coins: 2) { $0.bestWorm >= 40 },
        Medal(id: "s4", name: "보물 4단계", coins: 1) { $0.bestShiny >= 4 },
        Medal(id: "s6", name: "보물 6단계", coins: 2) { $0.bestShiny >= 6 },
        Medal(id: "f180", name: "함께 집중 3시간", coins: 1) { $0.focusMin >= 180 },
        Medal(id: "f1440", name: "함께 집중 24시간", coins: 3) { $0.focusMin >= 1440 },
        Medal(id: "n3", name: "장식된 둥지", coins: 2) { $0.nest >= 2 }
    ]
    static let bonds = [
        Bond(min: 0, name: "낯가림", note: ""),
        Bond(min: 20, name: "친구", note: "쓰다듬으면 기뻐해요"),
        Bond(min: 40, name: "단짝", note: "먼저 다가와요"),
        Bond(min: 60, name: "가족", note: "하루 한 번 선물을 물어 와요"),
        Bond(min: 80, name: "평생 친구", note: "날개를 펼쳐 인사해요")
    ]

    static func itemName(_ id: String) -> String { items.first { $0.id == id }?.name ?? id }
    static func genre(_ id: String?) -> Genre? { genres.first { $0.id == id } }
    static func duration(_ minutes: Int) -> String { minutes < 60 ? "\(minutes)분" : "\(minutes / 60)시간" }
    static func currencyName(_ key: String) -> String { key == "gem" ? "보석" : "도토리" }
}
