import SwiftUI
import Combine

@main
struct TakeCareOfApp: App {
    @StateObject private var model = GameModel()
    var body: some SwiftUI.Scene {
        WindowGroup { RootView(model: model) }
    }
}

// MARK: 공통 조각

struct WideButton: View {
    let title: String
    var sub: String? = nil
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold)).multilineTextAlignment(.center)
                if let sub { Text(sub).font(.system(size: 10)).multilineTextAlignment(.center) }
            }
            .foregroundColor(enabled ? Palette.ink : Palette.lcd)
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.horizontal, 4)
            .background(Palette.lcd.opacity(enabled ? 1 : 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct ArtRow: View {
    let art: String
    let title: String
    let note: String
    var trailing = ""
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                PixelImage(key: art).frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    Text(note).font(.system(size: 10)).lineLimit(2).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if !trailing.isEmpty { Text(trailing).font(.system(size: 11, weight: .semibold)) }
            }
            .foregroundColor(enabled ? Palette.ink : Palette.lcd)
            .padding(3)
            .background(Palette.lcd.opacity(enabled ? 1 : 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

/// 메뉴 화면: 왼쪽 위 뒤로 버튼과 제목을 시계와 같은 줄에 직접 그려요.
struct MenuPage<Content: View>: View {
    let title: String
    let back: () -> Void
    var scroll = true
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 1) {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Palette.lcd)
                        .frame(width: 24, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 56)
            }
            .padding(.top, 8)
            .padding(.leading, 10)
            Group {
                if scroll { ScrollView { content() } } else { content() }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}

struct IconButton: View {
    let art: String
    let label: String
    var alert = false
    let frame: Int
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            PixelImage(key: art)
                .frame(width: 26, height: 26)
                .shadow(color: Palette.lcd, radius: 1)
                .shadow(color: Palette.lcd, radius: 1)
                .opacity(alert && frame % 4 < 2 ? 0.2 : 1)
                .frame(maxWidth: .infinity, minHeight: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct Gauge2: View {
    let label: String
    let value: Double
    var warn = true
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11)).frame(width: 34, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).stroke(Palette.lcd, lineWidth: 1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(warn && value < 25 ? Palette.low : Palette.lcd)
                        .frame(width: g.size.width * CGFloat(max(0, min(100, value))) / 100)
                }
            }
            .frame(height: 9)
            Text("\(Int(value.rounded()))").font(.system(size: 11, weight: .semibold)).frame(width: 22, alignment: .trailing)
        }
        .foregroundColor(.white)
    }
}

// MARK: 루트

struct RootView: View {
    @ObservedObject var model: GameModel
    @Environment(\.scenePhase) private var phase
    private let slow = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private let fast = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        content
            .onReceive(slow) { _ in model.tick() }
            .onReceive(fast) { _ in
                if model.worm != nil || model.shiny != nil { model.gameTick() }
                if model.rub != nil { model.rubTick() }
            }
            .onChange(of: phase) { _, new in if new != .active { model.save() } }
    }

    @ViewBuilder private var content: some View {
        if model.s.name.isEmpty {
            NameView(model: model)
        } else {
            switch model.page {
            case .home: HomeView(model: model)
            case .food: FoodView(model: model)
            case .foodShop: FoodShopView(model: model)
            case .play: PlayView(model: model)
            case .focusMenu: FocusMenuView(model: model)
            case .genre: GenreView(model: model)
            case .explore: ExploreView(model: model)
            case .loot: LootView(model: model)
            case .treasure: TreasureView(model: model)
            case .shop: ShopView(model: model)
            case .dress: DressView(model: model)
            case .goals: GoalsView(model: model)
            case .status: StatusView(model: model)
            case .worm: WormView(model: model)
            case .shiny: ShinyView(model: model)
            }
        }
    }
}

struct NameView: View {
    @ObservedObject var model: GameModel
    @State private var text = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                PixelImage(key: "crow/egg0").frame(width: 40, height: 46)
                Text("알의 이름을 지어 주세요").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                TextField("이름", text: $text).multilineTextAlignment(.center)
                WideButton(title: "시작하기") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    model.s.name = trimmed.isEmpty ? "까망이" : String(trimmed.prefix(6))
                    model.save()
                }
            }
        }
    }
}

// MARK: 메인

struct HomeView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        let needs = model.needs
        let busy = model.s.focusEnd != nil || model.s.breakEnd != nil || model.s.act != nil || model.rub != nil
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Canvas { context, canvasSize in
                    Scene.draw(Stage(context: context, size: canvasSize, width: 198, height: 242), model: model)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in model.touchChanged(logical(v.location, size)) }
                    .onEnded { v in model.touchEnded(logical(v.location, size)) })

                VStack(spacing: 2) {
                    if !busy { topRow(needs) }
                    Text(model.screenText)
                        .font(.system(size: model.timerText != nil && now() >= model.messageUntil && model.rub == nil ? 24 : 12, weight: .bold))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Palette.lcd.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Spacer(minLength: 0)
                    if let r = model.rub { rubBar(r) }
                    else if !busy { bottomRow(needs) }
                    else if model.s.act?.type == "walk" && !model.stepsAvailable {
                        Button("걸음 +500 (시험용)") { model.addTestSteps() }.font(.system(size: 11)).buttonStyle(.plain).foregroundColor(Palette.ink)
                    }
                }
                .padding(.top, 30)
                .padding(.bottom, 6)
                .padding(.horizontal, 6)

                if model.confirmEnd { endDialog }
            }
        }
        .ignoresSafeArea()
    }

    private var endDialog: some View {
        VStack(spacing: 5) {
            Text("활동을 끝내시겠어요?").font(.system(size: 14, weight: .bold)).foregroundColor(Palette.ink).multilineTextAlignment(.center)
            Text(model.endNote).font(.system(size: 11)).foregroundColor(Palette.ink).multilineTextAlignment(.center)
            HStack(spacing: 5) {
                Button("아니요") { model.confirmEnd = false }
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.lcd)
                    .frame(maxWidth: .infinity, minHeight: 34).background(Palette.mid).clipShape(RoundedRectangle(cornerRadius: 8)).buttonStyle(.plain)
                Button("네") { model.endActivity() }
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.lcd)
                    .frame(maxWidth: .infinity, minHeight: 34).background(Palette.ink).clipShape(RoundedRectangle(cornerRadius: 8)).buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Palette.lcd)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.ink, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
    }

    private func logical(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        let unit = max(size.width / 198, size.height / 242)
        return CGPoint(x: (p.x - (size.width - 198 * unit) / 2) / unit, y: (p.y - (size.height - 242 * unit) / 2) / unit)
    }

    private func topRow(_ n: Set<String>) -> some View {
        HStack(spacing: 0) {
            IconButton(art: "crow/ic_food", label: "식사", alert: n.contains("meal"), frame: model.frame) { model.open(.food) }
            IconButton(art: "crow/ic_game", label: "게임", alert: n.contains("game"), frame: model.frame) { model.open(.play) }
            IconButton(art: "crow/ic_out", label: "함께 집중", frame: model.frame) { model.open(.focusMenu) }
            IconButton(art: "crow/ic_pet", label: "쓰다듬기", frame: model.frame) { model.pet() }
        }
    }

    private func bottomRow(_ n: Set<String>) -> some View {
        HStack(spacing: 0) {
            IconButton(art: "crow/ic_clean", label: "씻기", alert: n.contains("wash"), frame: model.frame) { model.bath() }
            IconButton(art: "crow/ic_hosp", label: "병원", alert: n.contains("hosp"), frame: model.frame) { model.hospital() }
            IconButton(art: model.s.sleeping ? "icons/wake" : "crow/ic_sleep", label: model.s.sleeping ? "깨우기" : "잠자기", alert: n.contains("sleep"), frame: model.frame) { model.toggleSleep() }
            IconButton(art: "crow/nest_empty", label: "둥지", frame: model.frame) { model.open(.treasure) }
        }
    }

    private func rubBar(_ r: Rub) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Palette.lcd)
                RoundedRectangle(cornerRadius: 4).fill(Palette.ink).frame(width: g.size.width * r.progress)
                RoundedRectangle(cornerRadius: 4).stroke(Palette.ink, lineWidth: 1.5)
            }
        }
        .frame(height: 10)
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
    }

}

// MARK: 식사

struct FoodView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "식사", back: { model.page = .home }) {
            VStack(spacing: 4) {
                WideButton(title: "먹이 상점", sub: "도토리 \(model.s.acorn)개") { model.page = .foodShop }
                ArtRow(art: "foods/worm", title: "지렁이", note: "주식 · 배부름 +30", trailing: "무료") { model.feed("worm") }
                ForEach(Catalog.foods, id: \.id) { f in
                    if (model.s.food[f.id] ?? 0) > 0 {
                        ArtRow(art: "foods/" + f.id, title: f.name, note: f.note, trailing: "×\(model.s.food[f.id] ?? 0)") { model.feed(f.id) }
                    }
                }
                if model.s.hiddenFood > 0 {
                    Text("숨겨 둔 먹이 \(model.s.hiddenFood)개").font(.system(size: 11)).foregroundColor(.white)
                }
            }
        }
    }
}

struct FoodShopView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "먹이 상점 · 도토리 \(model.s.acorn)", back: { model.page = .food }) {
            VStack(spacing: 4) {
                Text("도토리는 게임에서 모아요.").font(.system(size: 11)).foregroundColor(.white)
                ForEach(Catalog.foods, id: \.id) { f in
                    ArtRow(art: "foods/" + f.id, title: "\(f.name) (보유 \(model.s.food[f.id] ?? 0))", note: f.note,
                           trailing: "\(f.price)", enabled: model.s.acorn >= f.price) { model.buyFood(f) }
                }
            }
        }
    }
}

// MARK: 게임

struct PlayView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "게임", back: { model.page = .home }) {
            VStack(spacing: 5) {
                WideButton(title: "지렁이 잡기", sub: "최고 \(model.s.bestWorm)점") { model.startWorm() }
                WideButton(title: "보물 기억하기", sub: "최고 \(model.s.bestShiny)단계") { model.startShiny() }
            }
        }
    }
}

struct GameHud: View {
    let lives: Int
    let middle: String
    let right: String
    var body: some View {
        HStack {
            Text(String(repeating: "♥", count: max(0, lives)) + String(repeating: "♡", count: max(0, 3 - lives)))
                .foregroundColor(.red)
            Spacer(minLength: 0)
            Text(middle).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            Text(right).foregroundColor(.white)
        }
        .font(.system(size: 12, weight: .bold))
    }
}

struct WormView: View {
    @ObservedObject var model: GameModel
    @State private var touching = false
    var body: some View {
        MenuPage(title: "지렁이 잡기", back: { model.worm = nil; model.page = .home }, scroll: false) {
        VStack(spacing: 2) {
            if let g = model.worm {
                GameHud(lives: g.lives, middle: "콤보 \(g.combo)", right: "\(g.score)점 \(Int(max(0, g.left).rounded(.up)))초")
                gameCanvas(g)
            }
        }
        }
    }
    private func gameCanvas(_ g: WormGame) -> some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { context, s in
                Scene.drawWorm(Stage(context: context, size: s, width: 198, height: 136), g)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !touching {
                        touching = true
                        let st = max(size.width / 198, size.height / 136)
                        model.tapWorm(CGPoint(x: (v.location.x - (size.width - 198 * st) / 2) / st, y: (v.location.y - (size.height - 136 * st) / 2) / st))
                    }
                }
                .onEnded { _ in touching = false })
        }
        .aspectRatio(198.0 / 136.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ShinyView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "보물 기억하기", back: { model.shiny = nil; model.page = .home }, scroll: false) {
        VStack(spacing: 2) {
            if let g = model.shiny {
                GameHud(lives: g.lives, middle: phaseText(g), right: "\(g.level)단계")
                GeometryReader { geo in
                    let size = geo.size
                    Canvas { context, s in
                        Scene.drawShiny(Stage(context: context, size: s, width: 198, height: 136), g)
                    }
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { v in
                        let st = max(size.width / 198, size.height / 136)
                        model.tapShiny(CGPoint(x: (v.location.x - (size.width - 198 * st) / 2) / st, y: (v.location.y - (size.height - 136 * st) / 2) / st))
                    })
                }
                .aspectRatio(198.0 / 136.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        }
    }
    private func phaseText(_ g: ShinyGame) -> String {
        switch g.phase {
        case "show": return "외워요!"
        case "wind": return "바람!"
        case "clear": return "성공!"
        case "dead": return "아쉬워요"
        default: return "찾아요"
        }
    }
}

// MARK: 함께 집중

struct FocusMenuView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "함께 집중", back: { model.page = .home }) {
            VStack(spacing: 4) {
                row("explore", "탐험", "시간을 골라 보내요") { model.page = .explore }
                row("read", "책읽기", "책을 골라 읽고 직접 끝내요") { model.page = .genre }
                row("walk", "산책", "걸은 만큼 보상을 받아요") { model.startAct("walk") }
                Text("한 번에 하나만 할 수 있어요.").font(.system(size: 10)).foregroundColor(.white)
            }
        }
    }
    private func row(_ id: String, _ title: String, _ note: String, _ action: @escaping () -> Void) -> some View {
        let next = model.nextMile(id)
        let tail = next.map { " · \($0.count)회: \($0.name)" } ?? ""
        return WideButton(title: title, sub: "\(note)\n\(model.s.count[id] ?? 0)회\(tail)", action: action)
    }
}

struct GenreView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "무슨 책을 읽을까요?", back: { model.page = .focusMenu }) {
            VStack(spacing: 4) {
                ForEach(Catalog.genres, id: \.id) { g in
                    let c = model.s.genreCount[g.id] ?? 0
                    ArtRow(art: "hats/book_" + g.id, title: "\(g.name) · \(c)회",
                           note: c < 3 ? "3회: \(g.hatName)" : c < 7 ? "7회: 호칭 \(g.title)" : "전용 보상 완료") {
                        model.startAct("read", genre: g.id)
                    }
                }
            }
        }
    }
}

struct ExploreView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "탐험", back: { model.page = .focusMenu }) {
            VStack(spacing: 4) {
                ForEach(Array(Catalog.courses.enumerated()), id: \.offset) { i, c in
                    row(i, c)
                }
            }
        }
    }
    @ViewBuilder private func row(_ i: Int, _ c: Course) -> some View {
        if let need = c.need, model.s.stage != "adult" {
            let _ = need
            EmptyView()
        } else if let need = c.need, !model.s.owned.contains(need) {
            if need == "river" {
                WideButton(title: "\(Catalog.duration(c.minutes)) · \(c.title) · 잠김", sub: "상점에서 강가 지도를 사요", enabled: false) {}
            } else {
                let hasKey = (model.s.inv["key"] ?? 0) > 0
                WideButton(title: "\(Catalog.duration(c.minutes)) · \(c.title) · 잠김", sub: hasKey ? "열쇠 1개로 영구히 열어요" : "열쇠가 필요해요", enabled: hasKey) { model.unlockValley() }
            }
        } else {
            WideButton(title: "\(Catalog.duration(c.minutes)) · \(c.title)", sub: reward(c)) { model.startFocus(i) }
        }
    }
    private func reward(_ c: Course) -> String {
        switch model.s.stage {
        case "baby": return "기분 +\(Int(min(30, Double(c.minutes) * 0.4)))"
        case "teen": return "물건 \(c.loot)개"
        default:
            if c.hidden > 0 { return "보물 \(c.loot)개 · 골짜기 전용 50%" }
            if c.coin > 0 { return "보물 \(c.loot)개 · 동전 40%" }
            return "보물 \(c.loot)개 · 희귀 \(Int(c.rare * 100))%"
        }
    }
}

struct LootView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                if let l = model.loot {
                    Text(l.head ?? (l.early ? "일찍 돌아왔어요" : "집중 완료!")).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    let gains = [l.acorn > 0 ? "도토리 +\(l.acorn)" : "", l.coin > 0 ? "동전 +\(l.coin)" : "", l.gem > 0 ? "보석 +\(l.gem)" : ""].filter { !$0.isEmpty }
                    if !gains.isEmpty { caption(gains.joined(separator: " · ")) }
                    ForEach(l.unlock, id: \.self) { caption("전용 보상: \($0)") }
                    if !l.note.isEmpty { caption(l.note) }
                    if l.early && l.items.isEmpty { caption("빈손이에요. 다음엔 끝까지 같이 해요.") }
                    let counts = Dictionary(grouping: l.items, by: { $0 }).map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
                    ForEach(counts, id: \.0) { id, n in
                        ArtRow(art: "items/" + id, title: Catalog.itemName(id), note: "", trailing: "×\(n)") {}
                    }
                    if l.rest > 0 {
                        WideButton(title: "\(l.rest)분 같이 쉬기") { model.startRest() }
                        Button("건너뛰기") { model.closeLoot() }.font(.system(size: 12)).foregroundColor(.white).buttonStyle(.plain)
                    } else {
                        WideButton(title: "둥지로 돌아가기") { model.closeLoot() }
                    }
                }
            }
        }
    }
    private func caption(_ t: String) -> some View {
        Text(t).font(.system(size: 11)).foregroundColor(.white).multilineTextAlignment(.center)
    }
}

// MARK: 둥지

struct TreasureView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "\(model.s.name)의 보물상자", back: { model.page = .home }) {
            VStack(spacing: 4) {
                Text("\(model.stageLabel) · \(model.personality)").font(.system(size: 11)).foregroundColor(.white)
                if model.s.nest < 2 {
                    WideButton(title: model.s.nest == 0 ? "푹신한 둥지 만들기" : "장식된 둥지 만들기",
                               sub: model.s.nest == 0 ? "나뭇가지 2" : "깃털 2, 단추 1", enabled: model.canUpgradeNest) { model.upgradeNest() }
                }
                HStack(spacing: 4) {
                    WideButton(title: "상점", sub: "동전 \(model.s.inv["coin"] ?? 0)") { model.page = .shop }
                    WideButton(title: "꾸미기", sub: "보석 \(model.s.gem)") { model.page = .dress }
                }
                WideButton(title: "세트·메달") { model.page = .goals }
                Text("물건을 누르면 둥지에 진열해요 (\(model.s.display.count)/4)").font(.system(size: 10)).foregroundColor(.white)
                ForEach(Catalog.items, id: \.id) { it in
                    let n = model.s.inv[it.id] ?? 0
                    let known = model.s.seen.contains(it.id) || n > 0
                    ArtRow(art: known ? "items/" + it.id : "bubbles/question", title: known ? it.name : "???",
                           note: model.s.display.contains(it.id) ? "진열 중" : "\(it.rarity) · \(it.use)", trailing: "\(n)") { model.toggleDisplay(it.id) }
                }
                speedRow
                Button(model.confirmReset ? "한 번 더 누르면 새 알로 시작해요" : "새 알로 다시 시작") {
                    if model.confirmReset { model.restart() } else { model.confirmReset = true }
                }
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.7)).buttonStyle(.plain)
            }
        }
    }
    /// 시험용 속도 설정. 출시 전에 없앨 거예요.
    private var speedRow: some View {
        VStack(spacing: 4) {
        WideButton(title: "시험 시간대: \(model.testHour.map { "\(Int($0))시" } ?? "자동")", sub: "눌러서 시간대를 바꿔요") { model.cycleTestHour() }
        WideButton(title: "시험 속도: \(Int(model.s.speed))배", sub: "눌러서 1배, 60배, 360배로 바꿔요") {
            model.s.speed = model.s.speed == 1 ? 60 : model.s.speed == 60 ? 360 : 1
            model.save()
        }
        }
    }
}

struct ShopView: View {
    @ObservedObject var model: GameModel
    private var coins: Int { model.s.inv["coin"] ?? 0 }
    var body: some View {
        MenuPage(title: "상점 · 동전 \(coins)개", back: { model.page = .treasure }) {
            VStack(spacing: 4) {
                WideButton(title: "특별 간식", sub: "동전 1 · 기분 +30, 배부름 +20", enabled: coins >= 1) { model.buySnack() }
                ForEach(Catalog.shop, id: \.id) { it in
                    let owned = model.s.owned.contains(it.id)
                    WideButton(title: it.name, sub: owned ? "구입 완료" : "동전 \(it.price)", enabled: !owned && coins >= it.price) { model.buy(it) }
                }
                exchange("stone", "돌멩이")
                exchange("cap", "병뚜껑")
            }
        }
    }
    private func exchange(_ id: String, _ name: String) -> some View {
        let have = model.s.inv[id] ?? 0
        return WideButton(title: "\(name) 3개 → 동전 1개", sub: "가진 \(name) \(have)개", enabled: have >= 3) { model.exchange(id) }
    }
}

struct DressView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "꾸미기", back: { model.page = .treasure }) {
            VStack(spacing: 4) {
                Text("도토리 \(model.s.acorn) · 보석 \(model.s.gem)").font(.system(size: 11)).foregroundColor(.white)
                if model.s.stage != "egg" {
                    Canvas { context, size in
                        let st = Stage(context: context, size: size, width: 120, height: 108)
                        st.fill(Palette.lcd, 0, 0, 120, 108)
                        let f = Art.crow(model.s.stage + "_front")
                        let x = (120 - f.width) / 2, y = 106 - f.height
                        st.draw(f, x, y)
                        if let a = f.anchor, !model.s.hat.isEmpty {
                            let hat = Art.sprite("hats/\(model.s.hat)_\(model.s.stage)")
                            st.draw(hat, x + a.x - hat.width / 2, y + a.y + Int(Double(hat.height) * 0.35) - hat.height)
                        }
                    }
                    .frame(width: 84, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                ForEach(Catalog.cosmetics, id: \.id) { c in
                    let own = model.s.cos.contains(c.id)
                    let on = c.id == "aura" ? model.s.aura : model.s.hat == c.id
                    let money = c.currency == "gem" ? model.s.gem : model.s.acorn
                    ArtRow(art: c.id == "aura" ? "crow/st_spark" : "hats/\(c.id)_adult", title: c.name,
                           note: own ? (on ? "착용 중 · 누르면 벗어요" : "누르면 착용해요") : "\(Catalog.currencyName(c.currency)) \(c.price)",
                           enabled: own || money >= c.price) { model.pick(c) }
                }
                ForEach(["explore", "read", "walk"], id: \.self) { kind in
                    ForEach((Catalog.miles[kind] ?? []).filter { $0.isHat }, id: \.value) { m in
                        unlockRow(id: m.value, name: m.name, lock: "\(Catalog.actNames[kind] ?? "") \(m.count)회 전용")
                    }
                }
                ForEach(Catalog.genres, id: \.id) { g in
                    unlockRow(id: g.hat, name: g.hatName, lock: "\(g.name) 3회 전용")
                }
                Text("보석은 3시간 이상 함께 집중과 세트 완성으로 받아요.").font(.system(size: 10)).foregroundColor(.white).multilineTextAlignment(.center)
            }
        }
    }
    private func unlockRow(id: String, name: String, lock: String) -> some View {
        let own = model.s.cos.contains(id)
        return ArtRow(art: own ? "hats/\(id)_adult" : "bubbles/question", title: own ? name : "???",
                      note: own ? (model.s.hat == id ? "착용 중 · 누르면 벗어요" : "누르면 착용해요") : lock, enabled: own) { model.toggleHat(id) }
    }
}

struct GoalsView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        MenuPage(title: "세트·메달", back: { model.page = .treasure }) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Catalog.sets, id: \.id) { set in
                    let have = set.items.filter { model.s.seen.contains($0) }.count
                    line("\(model.s.sets.contains(set.id) ? "완성 " : "")\(set.name) \(have)/\(set.items.count)", set.note)
                }
                ForEach(Catalog.genres, id: \.id) { g in
                    line("\(g.name) 책 \(model.s.genreCount[g.id] ?? 0)회", "3회 \(g.hatName) · 7회 호칭 \(g.title)")
                }
                ForEach(Catalog.medals, id: \.id) { m in
                    line("\(model.s.medals.contains(m.id) ? "획득" : "미획득") \(m.name)", "보상 동전 \(m.coins)개")
                }
            }
        }
    }
    private func line(_ a: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(a).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
            Text(b).font(.system(size: 10)).foregroundColor(Palette.lcd)
        }
    }
}

struct StatusView: View {
    @ObservedObject var model: GameModel
    var body: some View {
        let level = model.bondLevel
        let bond = Catalog.bonds[level]
        MenuPage(title: "상태", back: { model.page = .home }) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(model.s.name) · \(model.stageLabel)").font(.system(size: 16, weight: .bold)).foregroundColor(Palette.lcd).lineLimit(1).minimumScaleFactor(0.7)
                Text("\(Int(model.s.age / 1440))일째 · \(model.personality)\(model.s.sick ? " · 아픔" : model.s.sleeping ? " · 자는 중" : "")")
                    .font(.system(size: 11)).foregroundColor(.white)
                Text("도토리 \(model.s.acorn) · 동전 \(model.s.inv["coin"] ?? 0) · 보석 \(model.s.gem)")
                    .font(.system(size: 11)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                Gauge2(label: "배부름", value: model.s.hunger)
                Gauge2(label: "기분", value: model.s.happy)
                Gauge2(label: "체력", value: model.s.energy)
                Gauge2(label: "청결", value: model.s.clean)
                Gauge2(label: "애정", value: model.s.bond, warn: false)
                Text("애정 단계: \(bond.name)\(bond.note.isEmpty ? "" : " · \(bond.note)")").font(.system(size: 11)).foregroundColor(.white)
                if level + 1 < Catalog.bonds.count {
                    let next = Catalog.bonds[level + 1]
                    Text("다음 \(Int(next.min)) · \(next.name): \(next.note)").font(.system(size: 10)).foregroundColor(Palette.lcd)
                }
            }
        }
    }
}
