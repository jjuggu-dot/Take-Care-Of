import SwiftUI
import Combine
import CoreMotion
import UserNotifications
#if os(watchOS)
import WatchKit
#endif

struct Activity: Codable {
    var type: String
    var start: Date
    var steps = 0
    var genre: String?
}

struct GameState: Codable {
    var name = ""
    var stage = "egg"
    var age = 0.0
    var eggTime = 8.0
    var hunger = 80.0, happy = 80.0, energy = 90.0, clean = 90.0, bond = 10.0
    var sick = false, sleeping = false
    var hiddenFood = 0
    var neglect = 0.0
    var awayUntil: Double?
    var inv: [String: Int] = [:]
    var nest = 0, total = 0, focusMin = 0, focusCount = 0
    var focusEnd: Date?
    var course = 1
    var breakEnd: Date?
    var lastShiny = -1000.0
    var lastPet = -999.0
    var lastGift: Double?
    var bestWorm = 0, bestShiny = 0
    var genreCount: [String: Int] = [:]
    var count: [String: Int] = ["explore": 0, "read": 0, "walk": 0]
    var act: Activity?
    var title = ""
    var acorn = 0, gem = 0
    var cos: Set<String> = []
    var hat = ""
    var aura = false
    var food: [String: Int] = ["berry": 1, "bread": 1]
    var seen: Set<String> = []
    var display: [String] = []
    var owned: Set<String> = []
    var medals: Set<String> = []
    var sets: Set<String> = []
    var speed = 1.0
    var saved = Date()
}

enum Page { case home, food, foodShop, play, focusMenu, genre, explore, loot, treasure, shop, dress, goals, status, worm, shiny }

struct Loot {
    var items: [String] = []
    var rest = 0
    var early = false
    var head: String?
    var acorn = 0, coin = 0, gem = 0
    var unlock: [String] = []
    var note = ""
}

struct Pop { var x, y, born: Double; var drift: Double }
struct Rub {
    var type: String
    var progress = 0.0
    var last: CGPoint?
    var pointer: CGPoint?
    var movedAt = 0.0
    var idleAt: Double
    var startClean: Double
    var startedAt: Double
    var pops: [Pop] = []
    var sincePop = 0.0
}

struct WormSlot { var type: String; var born: Double; var until: Double }
struct WormFx { var x, y: Double; var text: String; var until: Double; var spark: Bool }
struct WormGame {
    var start: Double
    var left = 30.0
    var lives = 3, score = 0, combo = 0, hop = 0
    var next: Double
    var last: Double
    var slots: [WormSlot?] = Array(repeating: nil, count: 6)
    var fx: [WormFx] = []
}

struct ShinyGame {
    var level = 1, lives = 3
    var cells: [String?] = Array(repeating: nil, count: 12)
    var found: [Int] = []
    var wrong = -1
    var wrongUntil = 0.0
    var phase = "show"
    var until = 0.0
    var swaps = 0
    var swap: (Int, Int)?
    var swapStart = 0.0, swapEnd = 0.0
}

func now() -> Double { Date().timeIntervalSince1970 }

final class GameModel: ObservableObject {
    @Published var s = GameState()
    @Published var page: Page = .home
    @Published var frame = 0
    @Published var message = ""
    @Published var loot: Loot?
    @Published var rub: Rub?
    @Published var worm: WormGame?
    @Published var shiny: ShinyGame?
    @Published var confirmReset = false

    var messageUntil = 0.0
    var anim = ""
    var animStart = 0.0, animUntil = 0.0
    var x = 50, left = false, walking = true, front = true, modeTimer = 0
    var bubble = "", bubbleTimer = 0
    var approachTimer = 0, greetTimer = 0
    private var lastTick = Date()
    private let pedometer = CMPedometer()
    private var countingSteps = false
    private let key = "crow-state-v1"

    static let holes: [(x: Double, y: Double)] = [(38, 98), (99, 98), (160, 98), (38, 131), (99, 131), (160, 131)]

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(GameState.self, from: data) {
            s = saved
        }
        applyDemo()
        let away = Date().timeIntervalSince(s.saved)
        if away > 30 { advance(away) }
        if s.act?.type == "walk" { startPedometer() }
    }

    /// 시뮬레이터 스크린샷용 상태. 실제 앱에서는 환경 변수가 없어 동작하지 않아요.
    private func applyDemo() {
        let env = ProcessInfo.processInfo.environment
        guard let demo = env["CROW_DEMO"] else { return }
        s = GameState()
        s.name = "까망"
        s.stage = env["CROW_STAGE"] ?? "adult"
        s.age = s.stage == "adult" ? 6000 : s.stage == "teen" ? 2000 : 100
        s.inv = ["twig": 3, "feather": 2, "button": 1, "coin": 6, "stone": 2, "key": 1]
        s.seen = ["twig", "feather", "button", "coin", "stone", "key"]
        s.display = ["coin", "feather"]
        s.acorn = 24; s.gem = 6
        s.hat = env["CROW_HAT"] ?? ""
        s.saved = Date()
        s.owned = ["deco_flower"]
        if env["CROW_SICK"] != nil { s.sick = true }
        front = true; walking = false; modeTimer = 9999; x = 12
        switch demo {
        case "status": page = .status
        case "food": page = .food
        case "foodshop": page = .foodShop
        case "focus": page = .focusMenu
        case "genre": page = .genre
        case "explore": page = .explore
        case "treasure": page = .treasure
        case "shop": page = .shop
        case "dress": page = .dress
        case "goals": page = .goals
        case "play": page = .play
        case "worm": startWorm()
        case "shiny": startShiny()
        case "read": s.act = Activity(type: "read", start: Date().addingTimeInterval(-754), genre: "romance")
        case "walk": s.act = Activity(type: "walk", start: Date(), steps: 3200)
        case "wash": startRub("wash")
        case "pet": startRub("pet")
        case "sleep": s.sleeping = true
        default: break
        }
    }

    // MARK: 표시용

    var stageLabel: String {
        switch s.stage {
        case "egg": return "알"
        case "baby": return "아기"
        case "teen": return "청소년기"
        default: return (s.inv["ring"] ?? 0) > 0 ? "반지의 까마귀" : "성체"
        }
    }

    var personality: String {
        if !s.title.isEmpty { return s.title }
        if s.sets.contains("valley") { return "골짜기 탐험가" }
        if s.sets.contains("rare") { return "반짝이 수집가" }
        if s.total >= 20 { return "보물 수집가" }
        if s.total >= 5 { return "호기심쟁이" }
        if s.focusCount >= 5 { return "집중 친구" }
        return "둥지지기"
    }

    var scale: Double { max(1, s.speed) }
    var actMinutes: Double {
        guard let act = s.act else { return 0 }
        return Date().timeIntervalSince(act.start) / 60 * scale
    }
    var bondLevel: Int {
        var level = 0
        for (i, b) in Catalog.bonds.enumerated() where s.bond >= b.min { level = i }
        return level
    }
    var needs: Set<String> {
        var r: Set<String> = []
        if s.hunger < 25 { r.insert("meal") }
        if s.happy < 25 { r.insert("game") }
        if s.clean < 25 { r.insert("wash") }
        if s.sick { r.insert("hosp") }
        if s.energy < 20 { r.insert("sleep") }
        return r
    }

    static func clock(_ seconds: Double) -> String {
        let t = max(0, Int(seconds.rounded(.up)))
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    var timerText: String? {
        if let e = s.focusEnd { return Self.clock(e.timeIntervalSinceNow) }
        if let e = s.breakEnd { return Self.clock(e.timeIntervalSinceNow) }
        if let a = s.act {
            if a.type == "read" { return Self.clock(Date().timeIntervalSince(a.start) * scale) }
            return "\(a.steps)걸음"
        }
        return nil
    }

    var screenText: String {
        if let r = rub { return r.type == "pet" ? "까마귀를 문질러 주세요" : "거품으로 문질러 주세요" }
        if now() < messageUntil { return message }
        if s.awayUntil != nil { return "\(s.name)이(가) 둥지를 떠났어요" }
        if let t = timerText { return t }
        if s.stage == "egg" { return "곧 깨어나요" }
        return "\(s.name) · \(stageLabel)"
    }

    // MARK: 시간

    func tick() {
        let t = Date()
        let seconds = t.timeIntervalSince(lastTick)
        lastTick = t
        advance(seconds)
        frame += 1
        let n = t.timeIntervalSince1970
        if !anim.isEmpty && n > animUntil { anim = "" }
        if let r = rub, n - r.idleAt > 10 { rub = nil; save() }
        bondActs()
        behave()
        if frame % 40 == 0 { save() }
    }

    func gameTick() {
        let n = now()
        if worm != nil { tickWorm(n) }
        if shiny != nil { tickShiny(n) }
    }

    func advance(_ seconds: Double) {
        if s.stage == "egg" {
            if s.name.isEmpty { return }
            s.eggTime -= seconds
            if s.eggTime <= 0 {
                s.stage = "baby"; s.age = 0
                startAnim("evolve", 1.4); say("\(s.name) 태어났어요!")
                buzz()
            }
            return
        }
        var remaining = min(seconds / 60 * s.speed, 43200)
        while remaining > 0 {
            let dt = min(remaining, 5)
            step(dt)
            remaining -= dt
        }
        let t = Date()
        if let e = s.focusEnd, t >= e { completeFocus() }
        if let e = s.breakEnd, t >= e { completeBreak() }
        if s.act != nil, actMinutes >= 720 { finishAct() }
    }

    private func cl(_ v: Double) -> Double { max(0, min(100, v)) }

    private func step(_ dt: Double) {
        s.age += dt
        grow()
        if let until = s.awayUntil {
            if s.age >= until { comeBack() }
            return
        }
        let longFocus = s.focusEnd != nil && Catalog.courses[s.course].minutes >= 180
        if longFocus || (s.act != nil && actMinutes >= 180) {
            func slow(_ v: Double, _ span: Double) -> Double { v > 20 ? max(20, v - dt * 100 / span * 0.25) : v }
            s.hunger = slow(s.hunger, 360); s.happy = slow(s.happy, 480)
            s.clean = slow(s.clean, 720); s.energy = slow(s.energy, 720)
            return
        }
        if s.focusEnd != nil || s.breakEnd != nil || s.act != nil { return }
        if worm != nil || shiny != nil { return }
        let r = s.sleeping ? 0.3 : 1.0
        s.hunger = cl(s.hunger - dt * 100 / 360 * r)
        s.happy = cl(s.happy - dt * 100 / 480 * r - (s.sick ? dt * 0.1 : 0))
        s.clean = cl(s.clean - dt * 100 / 720 * r)
        if s.sleeping {
            s.energy = cl(s.energy + dt * 100 / 240)
            if s.energy >= 100 { s.sleeping = false; say("잘 잤어요") }
        } else {
            s.energy = cl(s.energy - dt * 100 / 720)
            if s.energy <= 0 { s.sleeping = true }
        }
        if !s.sick && s.clean < 20 && Double.random(in: 0..<1) < dt * 0.004 { s.sick = true; say("몸이 안 좋아요") }
        if s.hunger < 25 && s.hiddenFood > 0 {
            s.hiddenFood -= 1; s.hunger = cl(s.hunger + 30); say("숨긴 먹이를 찾았어요")
        }
        if s.hunger <= 0 || s.happy <= 0 {
            s.neglect += dt
            if s.neglect >= 240 { leave() }
        } else { s.neglect = 0 }
    }

    private func grow() {
        if s.stage == "baby" && s.age >= 1440 {
            s.stage = "teen"; startAnim("evolve", 1.6); say("청소년기가 됐어요"); buzz()
        } else if s.stage == "teen" && s.age >= 5760 {
            s.stage = "adult"; startAnim("evolve", 1.6); say("멋진 성체가 됐어요"); buzz()
        }
    }

    private func leave() {
        s.awayUntil = s.age + 120; s.neglect = 0; s.sleeping = false
        page = .home; worm = nil; shiny = nil; rub = nil
        save()
    }

    private func comeBack() {
        s.awayUntil = nil; s.hunger = 50; s.happy = 40
        s.energy = max(s.energy, 50); s.clean = max(s.clean, 50); s.bond = cl(s.bond - 10)
        say("\(s.name) 돌아왔어요"); buzz(); save()
    }

    func say(_ t: String, _ seconds: Double = 2.2) { message = t; messageUntil = now() + seconds }
    func startAnim(_ k: String, _ seconds: Double) { anim = k; animStart = now(); animUntil = animStart + seconds }
    func buzz() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    var canAct: Bool {
        if s.stage == "egg" { say("아직 알이에요"); return false }
        if s.awayUntil != nil { say("둥지를 떠나 있어요"); return false }
        if s.focusEnd != nil || s.act != nil { say("함께 집중 중이에요"); return false }
        return true
    }

    func open(_ p: Page) {
        if p == .treasure { confirmReset = false; page = p; return }
        guard canAct else { return }
        if s.sleeping { say("쿨쿨 자고 있어요"); return }
        if s.sick && (p == .play || p == .focusMenu || p == .explore) {
            say("아파서 병원이 먼저예요"); startAnim("no", 0.9); return
        }
        page = p
    }

    // MARK: 돌보기

    func feed(_ f: String) {
        page = .home
        guard canAct else { return }
        if f == "worm" && s.hunger >= 95 {
            if s.hiddenFood < 3 { s.hiddenFood += 1; say("먹이를 몰래 숨겼어요"); startAnim("joy", 1) }
            else { say("숨길 곳이 없어요"); startAnim("no", 0.9) }
            save(); return
        }
        if f != "worm" {
            guard (s.food[f] ?? 0) > 0 else { return }
            s.food[f, default: 0] -= 1
        }
        switch f {
        case "worm": s.hunger = cl(s.hunger + 30)
        case "berry": s.hunger = cl(s.hunger + 15); s.energy = cl(s.energy + 5); s.happy = cl(s.happy + 5)
        case "seed": s.happy = cl(s.happy + 10); s.hunger = cl(s.hunger + 5); s.energy = cl(s.energy + 10)
        case "grain": s.hunger = cl(s.hunger + 25); s.happy = cl(s.happy + 5)
        case "bread": s.happy = cl(s.happy + 15); s.hunger = cl(s.hunger + 10); s.clean = cl(s.clean - 10)
        case "fish": s.hunger = cl(s.hunger + 40); s.happy = cl(s.happy + 10); s.bond = cl(s.bond + 1)
        default: break
        }
        s.bond = cl(s.bond + 0.5)
        startAnim("bread", 1.5); buzz(); save()
    }

    func buyFood(_ f: Food) {
        guard s.acorn >= f.price else { return }
        s.acorn -= f.price; s.food[f.id, default: 0] += 1; say("\(f.name) 구입!"); save()
    }

    func toggleSleep() {
        guard canAct else { return }
        if !s.sleeping && s.energy >= 90 { say("아직 안 졸려요"); startAnim("no", 0.9); return }
        s.sleeping.toggle(); buzz(); save()
    }

    func bath() {
        guard canAct else { return }
        if s.sleeping { say("쿨쿨 자고 있어요"); return }
        if s.clean >= 95 { say("이미 깨끗해요"); return }
        startRub("wash")
    }

    func pet() {
        guard canAct else { return }
        if s.sleeping { say("쿨쿨 자고 있어요"); return }
        startRub("pet")
    }

    func hospital() {
        guard canAct else { return }
        if !s.sick { say("진찰 결과 건강해요!"); startAnim("joy", 1); return }
        s.sick = false; s.sleeping = false; s.happy = cl(s.happy - 5); s.bond = cl(s.bond + 1)
        s.clean = max(s.clean, 40)
        startAnim("cure", 1.8); say("주사 맞고 다 나았어요"); buzz(); save()
    }

    // MARK: 문지르기

    func startRub(_ type: String) {
        rub = Rub(type: type, idleAt: now(), startClean: s.clean, startedAt: now())
        anim = ""; messageUntil = 0
    }

    /// 까마귀가 정면으로 다가온 모습의 크기와 위치
    func closeUp(_ sprite: Sprite, at time: Double) -> (scale: Double, x: Double, y: Double) {
        let p = min(1, (time - (rub?.startedAt ?? time)) / 0.45)
        let t = 1 - (1 - p) * (1 - p)
        let target = 150 / Double(max(1, sprite.height))
        let scale = 1 + (target - 1) * t
        return (scale, (198 - Double(sprite.width) * scale) / 2, 198 + 28 * t - Double(sprite.height) * scale)
    }

    private func insideCrow(_ p: CGPoint) -> Bool {
        let sprite = Art.crow(s.stage + "_front")
        let c = closeUp(sprite, at: now() + 1)
        let w = Double(sprite.width) * c.scale
        return p.x >= c.x - 8 && p.x <= c.x + w + 8 && p.y >= c.y - 8 && p.y <= 230
    }

    func rubMoved(to p: CGPoint) {
        guard var r = rub else { return }
        let n = now()
        let inside = insideCrow(p)
        r.pointer = p; r.idleAt = n
        if inside, let l = r.last {
            let d = hypot(p.x - l.x, p.y - l.y)
            r.progress = min(1, r.progress + d / (r.type == "pet" ? 200 : 320))
            r.movedAt = n
            r.sincePop += d
            if r.sincePop >= 16 {
                r.sincePop = 0
                r.pops.append(Pop(x: p.x, y: p.y, born: n, drift: Double.random(in: -14...14)))
                if r.pops.count > 14 { r.pops.removeFirst() }
                buzz()
            }
            if r.type == "wash" { s.clean = cl(r.startClean + (100 - r.startClean) * r.progress) }
        }
        r.last = inside ? p : nil
        rub = r
        if r.progress >= 1 { finishRub() }
    }

    func rubTick() {
        guard var r = rub else { return }
        let n = now()
        r.pops.removeAll { n - $0.born > 0.9 }
        rub = r
    }

    // MARK: 터치 (누르기, 문지르기, 옆으로 밀기)

    private var touchStart: CGPoint?
    private var touchStartedOnCrow = false
    private var swipeArmedUntil = 0.0

    var isBusy: Bool { s.focusEnd != nil || s.breakEnd != nil || s.act != nil || rub != nil }

    func touchChanged(_ p: CGPoint) {
        if touchStart == nil {
            touchStart = p
            touchStartedOnCrow = rub != nil && insideCrow(p)
            if rub != nil { rub?.last = nil }
        }
        if rub != nil && touchStartedOnCrow { rubMoved(to: p) }
    }

    func touchEnded(_ p: CGPoint) {
        defer { touchStart = nil; rub?.last = nil }
        guard let start = touchStart else { return }
        let dx = p.x - start.x, dy = p.y - start.y
        if abs(dx) > 40 && abs(dx) > abs(dy) * 1.5 {
            if rub == nil || !touchStartedOnCrow { swipe() }
            return
        }
        if hypot(dx, dy) < 8 && rub == nil { tapScene(p) }
    }

    /// 옆으로 밀면 그만둬요. 집중 활동은 실수를 막으려고 2.5초 안에 한 번 더 밀어야 끝나요.
    private func swipe() {
        if rub != nil { cancelRub(); return }
        if s.breakEnd != nil { endRest(); return }
        guard s.focusEnd != nil || s.act != nil else { return }
        if now() < swipeArmedUntil {
            swipeArmedUntil = 0
            messageUntil = 0
            if s.focusEnd != nil { recall() } else { finishAct() }
        } else {
            swipeArmedUntil = now() + 2.5
            let long = s.focusEnd != nil && Catalog.courses[s.course].minutes < 180
            say(long ? "한 번 더 밀면 빈손으로 돌아와요" : "한 번 더 밀면 끝나요", 2.5)
            buzz()
        }
    }

    func rubEnded() { rub?.last = nil }

    private func finishRub() {
        guard let r = rub else { return }
        rub = nil
        if r.type == "pet" {
            if s.age - s.lastPet >= 30 {
                s.happy = cl(s.happy + 8); s.bond = cl(s.bond + 1); s.lastPet = s.age; say("기분이 좋아졌어요")
            } else { s.happy = cl(s.happy + 1); say("좋아해요") }
        } else {
            s.clean = 100; s.happy = cl(s.happy + 3); s.bond = cl(s.bond + 0.5); say("깨끗해졌어요")
        }
        startAnim("joy", 1.4); save()
    }

    func cancelRub() { rub = nil; save() }

    // MARK: 함께 집중

    func startFocus(_ i: Int) {
        guard canAct else { return }
        s.sleeping = false; s.course = i
        let seconds = Double(Catalog.courses[i].minutes * 60) / scale
        s.focusEnd = Date().addingTimeInterval(seconds)
        page = .home
        notify(after: seconds, title: "\(s.name) 돌아왔어요", body: "전리품을 확인하고 함께 쉬어요.")
        say("옆으로 두 번 밀면 일찍 불러요", 2.5)
        buzz(); save()
    }

    func unlockValley() {
        guard (s.inv["key"] ?? 0) >= 1, !s.owned.contains("valley") else { return }
        s.inv["key", default: 0] -= 1; s.owned.insert("valley"); say("숨겨진 골짜기가 열렸어요", 3); save()
    }

    private func rollItem(_ rare: Double, _ ring: Double) -> String {
        if s.stage != "adult" { return Catalog.common.randomElement()! }
        let r = Double.random(in: 0..<1)
        if r < ring { return "ring" }
        if r < ring + rare { return Catalog.rare.randomElement()! }
        return Catalog.common.randomElement()!
    }

    private func rollCourse(_ c: Course, _ n: Int) -> [String] {
        if s.stage == "baby" { return [] }
        var out: [String] = []
        for _ in 0..<max(0, n) {
            let r = Double.random(in: 0..<1)
            let id: String
            if c.hidden > 0 && r < c.hidden { id = Catalog.hidden.randomElement()! }
            else if c.coin > 0 && r < c.coin { id = "coin" }
            else { id = rollItem(c.rare, c.ring) }
            out.append(id); addItem(id)
        }
        return out
    }

    private func addItem(_ id: String) {
        s.inv[id, default: 0] += 1; s.total += 1; s.seen.insert(id)
        if !s.display.contains(id) && s.display.count < 4 { s.display.append(id) }
    }

    func recall() {
        guard let end = s.focusEnd else { return }
        let c = Catalog.courses[s.course]
        let total = Double(c.minutes * 60) / scale
        let done = max(0, min(1, 1 - end.timeIntervalSinceNow / total))
        var found: [String] = []
        if c.minutes >= 180 {
            found = rollCourse(c, Int(Double(c.loot) * done))
            s.focusMin += Int(Double(c.minutes) * done)
        }
        s.focusEnd = nil
        cancelNotifications()
        var l = Loot(); l.items = found; l.early = true
        loot = l; page = .loot; save()
    }

    private func completeFocus() {
        let c = Catalog.courses[s.course]
        s.focusEnd = nil; s.focusMin += c.minutes; s.focusCount += 1
        s.happy = cl(s.happy + min(30, Double(c.minutes) * 0.4))
        s.bond = cl(s.bond + min(8, Double(c.minutes) / 12))
        var l = Loot()
        l.items = rollCourse(c, c.loot); l.rest = c.rest
        l.gem = c.minutes >= 720 ? 3 : c.minutes >= 540 ? 2 : c.minutes >= 180 ? 1 : 0
        s.gem += l.gem
        l.acorn = min(30, c.minutes / 10); l.coin = c.minutes / 120
        s.acorn += l.acorn; s.inv["coin", default: 0] += l.coin
        if l.coin > 0 { s.seen.insert("coin") }
        l.unlock = milestone("explore")
        worm = nil; shiny = nil; rub = nil
        loot = l; page = .loot; buzz(); save()
    }

    func startAct(_ type: String, genre: String? = nil) {
        guard canAct else { return }
        s.sleeping = false
        s.act = Activity(type: type, start: Date(), genre: genre)
        page = .home
        if type == "walk" { startPedometer() }
        say("옆으로 두 번 밀면 끝나요", 2.5)
        buzz(); save()
    }

    private func startPedometer() {
        guard !countingSteps, let start = s.act?.start, CMPedometer.isStepCountingAvailable() else { return }
        countingSteps = true
        pedometer.startUpdates(from: start) { [weak self] data, _ in
            guard let self, let steps = data?.numberOfSteps.intValue else { return }
            DispatchQueue.main.async { if self.s.act?.type == "walk" { self.s.act?.steps = steps } }
        }
    }

    var stepsAvailable: Bool { CMPedometer.isStepCountingAvailable() }
    func addTestSteps() { s.act?.steps += 500 }

    private func milestone(_ type: String) -> [String] {
        s.count[type, default: 0] += 1
        var got: [String] = []
        for m in Catalog.miles[type] ?? [] where m.count == s.count[type] {
            if m.isHat { s.cos.insert(m.value); s.hat = m.value } else { s.title = m.value }
            got.append(m.name)
        }
        return got
    }

    private func genreMile(_ id: String) -> [String] {
        guard let g = Catalog.genre(id) else { return [] }
        s.genreCount[id, default: 0] += 1
        let c = s.genreCount[id] ?? 0
        var got: [String] = []
        if c == 3 { s.cos.insert(g.hat); s.hat = g.hat; got.append(g.hatName) }
        if c == 7 { s.title = g.title; got.append("호칭 \(g.title)") }
        return got
    }

    func nextMile(_ type: String) -> Mile? {
        let c = s.count[type] ?? 0
        return (Catalog.miles[type] ?? []).first { $0.count > c }
    }

    func finishAct() {
        guard let a = s.act else { return }
        let m = actMinutes
        var gain = (acorn: 0, coin: 0, gem: 0)
        var counted = false
        var l = Loot()
        if a.type == "read" {
            gain = m >= 180 ? (25, 2, 1) : m >= 120 ? (20, 1, 0) : m >= 60 ? (10, 0, 0) : m >= 30 ? (5, 0, 0) : m >= 15 ? (3, 0, 0) : m >= 5 ? (1, 0, 0) : (0, 0, 0)
            counted = m >= 15
            let hours = m >= 60 ? "\(Int(m / 60))시간 " : ""
            l.head = "\(Catalog.genre(a.genre).map { $0.name + " " } ?? "")독서 \(hours)\(Int(m) % 60)분"
            if !counted { l.note = "15분 이상 읽으면 횟수가 쌓여요." }
        } else {
            gain = (min(20, a.steps / 1000 * 2), a.steps / 5000, a.steps >= 10000 ? 1 : 0)
            counted = a.steps >= 1000
            l.head = "산책 \(a.steps)걸음"
            if !counted { l.note = "1,000걸음 이상 걸으면 횟수가 쌓여요." }
            pedometer.stopUpdates(); countingSteps = false
        }
        s.act = nil
        s.acorn += gain.acorn; s.inv["coin", default: 0] += gain.coin
        if gain.coin > 0 { s.seen.insert("coin") }
        s.gem += gain.gem
        let scaleUp = min(1, a.type == "read" ? m / 60 : Double(a.steps) / 5000)
        s.happy = cl(s.happy + (15 * scaleUp).rounded())
        s.bond = cl(s.bond + (4 * scaleUp).rounded())
        if a.type == "read" { s.focusMin += Int(m) }
        if a.type == "walk" && a.steps >= 5000 && s.stage != "baby" {
            let id = rollItem(0.2, 0); addItem(id); l.items.append(id)
        }
        if counted {
            l.unlock = milestone(a.type)
            if let g = a.genre { l.unlock += genreMile(g) }
        }
        l.acorn = gain.acorn; l.coin = gain.coin; l.gem = gain.gem
        loot = l; page = .loot; buzz(); save()
    }

    func startRest() {
        if let r = loot?.rest, r > 0 {
            let seconds = Double(r * 60) / scale
            s.breakEnd = Date().addingTimeInterval(seconds)
            notify(after: seconds, title: "쉬는 시간 끝", body: "\(s.name)와 다음 집중을 시작해 볼까요?")
        }
        closeLoot(); save()
    }
    func closeLoot() { loot = nil; page = .home }
    func endRest() { s.breakEnd = nil; cancelNotifications(); save() }

    private func completeBreak() {
        s.breakEnd = nil
        s.happy = cl(s.happy + 10); s.energy = cl(s.energy + 15); s.bond = cl(s.bond + 2)
        say("함께 잘 쉬었어요"); startAnim("joy", 1.4); buzz(); save()
    }

    private func notify(after seconds: Double, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title; content.body = body; content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "crow-timer", content: content, trigger: trigger))
        }
    }
    private func cancelNotifications() { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }

    // MARK: 둥지, 상점, 꾸미기

    var canUpgradeNest: Bool {
        if s.nest == 0 { return (s.inv["twig"] ?? 0) >= 2 }
        if s.nest == 1 { return (s.inv["feather"] ?? 0) >= 2 && (s.inv["button"] ?? 0) >= 1 }
        return false
    }
    func upgradeNest() {
        guard canUpgradeNest else { return }
        if s.nest == 0 { s.inv["twig", default: 0] -= 2 }
        else { s.inv["feather", default: 0] -= 2; s.inv["button", default: 0] -= 1 }
        s.nest += 1; s.happy = cl(s.happy + 15)
        startAnim("joy", 1.4); say("둥지가 좋아졌어요"); page = .home; buzz(); save()
    }
    func buy(_ it: ShopItem) {
        guard (s.inv["coin"] ?? 0) >= it.price, !s.owned.contains(it.id) else { return }
        s.inv["coin", default: 0] -= it.price; s.owned.insert(it.id); say("\(it.name) 구입!"); save()
    }
    func buySnack() {
        guard canAct, !s.sleeping, (s.inv["coin"] ?? 0) >= 1 else { return }
        s.inv["coin", default: 0] -= 1
        s.happy = cl(s.happy + 30); s.hunger = cl(s.hunger + 20); s.bond = cl(s.bond + 1)
        page = .home; startAnim("bread", 1.5); save()
    }
    func exchange(_ id: String) {
        guard (s.inv[id] ?? 0) >= 3 else { return }
        s.inv[id, default: 0] -= 3; s.inv["coin", default: 0] += 1; s.seen.insert("coin"); save()
    }
    func toggleDisplay(_ id: String) {
        guard (s.inv[id] ?? 0) > 0 else { return }
        if let i = s.display.firstIndex(of: id) { s.display.remove(at: i) }
        else if s.display.count < 4 { s.display.append(id) }
        else { say("진열은 4개까지예요") }
        save()
    }
    func pick(_ c: Cosmetic) {
        if s.cos.contains(c.id) {
            if c.id == "aura" { s.aura.toggle() } else { s.hat = s.hat == c.id ? "" : c.id }
            save(); return
        }
        if c.currency == "gem" {
            guard s.gem >= c.price else { return }
            s.gem -= c.price
        } else {
            guard s.acorn >= c.price else { return }
            s.acorn -= c.price
        }
        s.cos.insert(c.id)
        if c.id == "aura" { s.aura = true } else { s.hat = c.id }
        say("\(c.name) 착용!"); save()
    }
    func toggleHat(_ id: String) {
        guard s.cos.contains(id) else { return }
        s.hat = s.hat == id ? "" : id; save()
    }

    private func checkGoals() {
        for set in Catalog.sets where !s.sets.contains(set.id) && set.items.allSatisfy({ s.seen.contains($0) }) {
            s.sets.insert(set.id); s.gem += 2; say("\(set.name) 완성! 보석 +2", 3)
        }
        for m in Catalog.medals where !s.medals.contains(m.id) && m.done(s) {
            s.medals.insert(m.id); s.inv["coin", default: 0] += m.coins; s.seen.insert("coin")
            say("메달: \(m.name)! 동전 +\(m.coins)", 3)
        }
    }

    func restart() {
        let speed = s.speed
        s = GameState(); s.speed = speed
        page = .home; loot = nil; anim = ""; messageUntil = 0; x = 50
        rub = nil; worm = nil; shiny = nil; confirmReset = false
        cancelNotifications(); save()
    }

    func save() {
        s.display = s.display.filter { (s.inv[$0] ?? 0) > 0 }
        checkGoals()
        s.saved = Date()
        if ProcessInfo.processInfo.environment["CROW_DEMO"] != nil { return }
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }

    // MARK: 행동

    var calm: Bool {
        rub == nil && !s.name.isEmpty && s.stage != "egg" && page == .home && worm == nil && shiny == nil && anim.isEmpty
        && !s.sleeping && !s.sick && s.focusEnd == nil && s.breakEnd == nil && s.act == nil && s.awayUntil == nil
        && s.hunger >= 25 && s.happy >= 25 && s.clean >= 25 && s.energy >= 20
    }

    private func bondActs() {
        guard calm else { return }
        let level = bondLevel
        if level >= 3 && (s.lastGift == nil || s.age - (s.lastGift ?? 0) >= 1440) {
            let id = rollItem(0.1, 0); addItem(id); s.lastGift = s.age
            say("선물을 물어 왔어요: \(Catalog.itemName(id))", 3); startAnim("joy", 1.4); buzz(); save()
            return
        }
        if level >= 2 && approachTimer == 0 && Double.random(in: 0..<1) < 0.02 { approachTimer = 28 }
        if level >= 4 && greetTimer == 0 && Double.random(in: 0..<1) < 0.01 { greetTimer = 8 }
    }

    private func behave() {
        modeTimer -= 1
        if modeTimer <= 0 {
            walking = Double.random(in: 0..<1) < 0.4
            front = Double.random(in: 0..<1) < 0.8
            left = Bool.random()
            modeTimer = walking ? Int.random(in: 8...20) : Int.random(in: 16...40)
        }
        let w = Art.crow((s.stage == "egg" ? "baby" : s.stage) + "_side").width
        let mx = 192 - w
        if approachTimer > 0 {
            approachTimer -= 1
            let tx = (198 - w) / 2
            if !calm { approachTimer = 0 }
            else if abs(x - tx) > 3 { walking = true; left = x > tx; x += left ? -3 : 3; bubble = ""; return }
            else { walking = false; front = true; bubble = "hearts"; modeTimer = max(modeTimer, 2); return }
        }
        if greetTimer > 0 { greetTimer -= 1 }
        if walking && anim.isEmpty && !s.sleeping && s.happy >= 25 && !s.sick && frame % 2 == 0 {
            x += left ? -3 : 3
            if x < 6 { x = 6; left = false }
            if x > mx { x = mx; left = true }
        }
        x = max(6, min(x, mx))
        bubbleTimer -= 1
        if bubbleTimer <= 0 {
            bubbleTimer = Int.random(in: 12...28)
            if s.bond >= 60 && Int.random(in: 0..<4) == 0 && !s.sleeping { bubble = "hearts" }
            else if s.happy > 75 && Int.random(in: 0..<3) == 0 && !s.sleeping { bubble = "heart" }
            else { bubble = "" }
        }
    }

    func pose(_ name: String, _ i: Int? = nil) -> Sprite {
        let prefix = s.stage == "adult" ? "a_" : s.stage == "teen" ? "t_" : "b_"
        return Art.crow(prefix + name + (i.map(String.init) ?? ""))
    }

    func nestSprite() -> Sprite {
        Art.crow("nest\(min(s.nest, 2))_\(s.stage == "egg" ? "baby" : s.stage)")
    }

    func tapScene(_ p: CGPoint) {
        if rub != nil || s.stage == "egg" || p.y < 36 { return }
        if s.focusEnd != nil || s.breakEnd != nil || s.act != nil || s.sleeping || s.awayUntil != nil {
            if s.awayUntil == nil { page = .status }
            return
        }
        let cr = Art.crow(s.stage + "_front")
        if Int(p.x) >= x - 6 && Int(p.x) <= x + cr.width + 10 && Int(p.y) >= 198 - cr.height { page = .status; return }
        let n = nestSprite()
        let nx = 192 - n.width
        if Int(p.x) >= nx && Int(p.x) <= nx + n.width && Int(p.y) >= 198 - n.height { open(.treasure) }
    }

    // MARK: 지렁이 잡기

    func startWorm() {
        let n = now()
        worm = WormGame(start: n, next: n + 0.5, last: n)
        page = .worm
    }

    private func tickWorm(_ n: Double) {
        guard var g = worm else { return }
        g.left -= n - g.last; g.last = n
        let p = min(1, (n - g.start) / 30)
        for i in 0..<6 {
            if let slot = g.slots[i], n > slot.until {
                if slot.type != "wasp" {
                    g.combo = 0; g.left -= 1
                    g.fx.append(WormFx(x: Self.holes[i].x, y: Self.holes[i].y - 20, text: "-1초", until: n + 0.6, spark: false))
                }
                g.slots[i] = nil
            }
        }
        if n >= g.next {
            let free = (0..<6).filter { g.slots[$0] == nil }
            if let at = free.randomElement() {
                let r = Double.random(in: 0..<1)
                let type = r < 0.1 ? "fat" : r < 0.22 + 0.2 * p ? "wasp" : "worm"
                let life = (1.25 - 0.7 * p) * (type == "fat" ? 0.65 : 1) * (type == "wasp" ? 1.4 : 1)
                g.slots[at] = WormSlot(type: type, born: n, until: n + life)
            }
            g.next = n + (0.8 - 0.48 * p) * Double.random(in: 0.8...1.2)
        }
        if g.hop > 0 { g.hop -= 1 }
        g.fx.removeAll { n >= $0.until }
        worm = g
        if g.left <= 0 || g.lives <= 0 { finishWorm(g) }
    }

    func tapWorm(_ p: CGPoint) {
        guard var g = worm else { return }
        var best = 0, bestD = Double.infinity
        for (i, h) in Self.holes.enumerated() {
            let d = abs(h.x - p.x) * 0.8 + abs((h.y - 16) - p.y)
            if d < bestD { bestD = d; best = i }
        }
        guard let slot = g.slots[best] else { return }
        let n = now()
        g.slots[best] = nil
        let h = Self.holes[best]
        if slot.type == "wasp" {
            g.lives -= 1; g.combo = 0
            g.fx.append(WormFx(x: h.x, y: h.y - 20, text: "아야!", until: n + 0.7, spark: true))
        } else {
            g.combo += 1
            let add = (slot.type == "fat" ? 3 : 1) * (g.combo >= 5 ? 2 : 1)
            g.score += add; g.hop = 5
            g.fx.append(WormFx(x: h.x, y: h.y - 20, text: "+\(add)", until: n + 0.6, spark: true))
        }
        buzz()
        worm = g
    }

    private func finishWorm(_ g: WormGame) {
        let win = g.score >= 20, record = g.score > s.bestWorm
        if record { s.bestWorm = g.score }
        s.hunger = cl(s.hunger + min(25, Double(g.score)))
        s.happy = cl(s.happy + (win ? 20 : min(12, Double(g.score))))
        s.bond = cl(s.bond + 1)
        let acorns = min(10, g.score / 4)
        s.acorn += acorns
        say("\(record ? "신기록! " : "")\(g.score)점 · 도토리 +\(acorns)", 2.8)
        startAnim("joy", 1.4); worm = nil; page = .home; save()
    }

    // MARK: 보물 기억하기

    func startShiny() {
        var g = ShinyGame()
        setupLevel(&g)
        shiny = g; page = .shiny
    }

    private func setupLevel(_ g: inout ShinyGame) {
        g.cells = Array(repeating: nil, count: 12)
        let count = min(2 + g.level, 8)
        let order = Array(0..<12).shuffled()
        let pool = Catalog.common + Catalog.rare + ["ring"]
        for k in 0..<count { g.cells[order[k]] = pool[k % pool.count] }
        g.found = []; g.wrong = -1; g.wrongUntil = 0
        g.phase = "show"; g.until = now() + max(1, 2.3 - 0.22 * Double(g.level))
        g.swaps = g.level >= 3 ? g.level - 2 : 0; g.swap = nil
    }

    private func tickShiny(_ n: Double) {
        guard var g = shiny else { return }
        if g.phase == "show" && n > g.until { g.phase = g.swaps > 0 ? "wind" : "play"; g.until = n + 0.35 }
        if g.phase == "wind" && n > g.until {
            if let sw = g.swap {
                g.cells.swapAt(sw.0, sw.1); g.swap = nil; g.swaps -= 1
                if g.swaps <= 0 { g.phase = "play" } else { g.until = n + 0.18 }
            } else {
                let treasure = (0..<12).filter { g.cells[$0] != nil }
                let empty = (0..<12).filter { g.cells[$0] == nil }
                if let a = treasure.randomElement(), let b = empty.randomElement() {
                    g.swap = (a, b); g.swapStart = n
                    g.until = n + max(0.42, 0.7 - 0.04 * Double(g.level)); g.swapEnd = g.until
                }
            }
        }
        if g.phase == "clear" && n > g.until {
            if g.level >= 6 { finishShiny(g, clear: true); return }
            g.level += 1; setupLevel(&g)
        }
        if g.phase == "dead" && n > g.until { finishShiny(g, clear: false); return }
        shiny = g
    }

    func tapShiny(_ p: CGPoint) {
        guard var g = shiny, g.phase == "play" else { return }
        let col = Int(p.x / 49), row = Int(p.y / 45)
        guard col >= 0, col <= 3, row >= 0, row <= 2 else { return }
        let i = row * 4 + col, n = now()
        if g.found.contains(i) { return }
        if g.cells[i] != nil {
            g.found.append(i)
            if g.found.count >= g.cells.compactMap({ $0 }).count { g.phase = "clear"; g.until = n + 0.8 }
        } else {
            g.lives -= 1; g.wrong = i; g.wrongUntil = n + 0.45
            if g.lives <= 0 { g.phase = "dead"; g.until = n + 0.9 }
        }
        buzz()
        shiny = g
    }

    private func finishShiny(_ g: ShinyGame, clear: Bool) {
        let level = clear ? 7 : g.level
        let record = level - 1 > s.bestShiny
        if record { s.bestShiny = level - 1 }
        let cleared = level - 1, acorns = cleared + (clear ? 2 : 0)
        s.acorn += acorns
        s.happy = cl(s.happy + Double(cleared) * 5); s.bond = cl(s.bond + 1)
        startAnim("joy", 1.2)
        if cleared >= 2 && s.age - s.lastShiny >= 60 && s.stage != "baby" {
            let id = cleared >= 6 ? rollItem(0.5, 0.05) : cleared >= 4 ? rollItem(0.3, 0) : Catalog.common.randomElement()!
            addItem(id); s.lastShiny = s.age
            say("\(Catalog.itemName(id)) 발견! 도토리 +\(acorns)", 2.8)
        } else {
            say("\(record ? "신기록! " : "")\(cleared)단계 · 도토리 +\(acorns)", 2.8)
        }
        shiny = nil; page = .home; save()
    }
}
