import SwiftUI

/// 198×242칸 화면을 실제 크기에 맞춰 그려요. 넓은 쪽을 채우고 넘치는 부분은 잘립니다.
struct Stage {
    var context: GraphicsContext
    let unit: CGFloat
    let ox: CGFloat
    let oy: CGFloat

    init(context: GraphicsContext, size: CGSize, width: CGFloat, height: CGFloat) {
        self.context = context
        unit = max(size.width / width, size.height / height)
        ox = (size.width - width * unit) / 2
        oy = (size.height - height * unit) / 2
    }

    func draw(_ s: Sprite, _ x: Int, _ y: Int, flip: Bool = false) {
        guard let cg = flip ? s.flipped : s.image else { return }
        draw(cg, x, y, s.width, s.height)
    }

    func draw(_ cg: CGImage, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        let rect = CGRect(x: ox + CGFloat(x) * unit, y: oy + CGFloat(y) * unit, width: CGFloat(w) * unit, height: CGFloat(h) * unit)
        context.draw(Image(decorative: cg, scale: 1).interpolation(.none), in: rect)
    }

    func fill(_ color: Color, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        let rect = CGRect(x: ox + CGFloat(x) * unit, y: oy + CGFloat(y) * unit, width: CGFloat(w) * unit, height: CGFloat(h) * unit)
        context.fill(Path(rect), with: .color(color))
    }

    func toLogical(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - ox) / unit, y: (p.y - oy) / unit) }
}

enum Scene {
    private static let ground = 198
    private static let screenW = 198

    private static func half(_ s: Sprite) -> (CGImage?, Int, Int) { (s.image, s.width / 2, s.height / 2) }

    private static func wear(_ st: Stage, _ m: GameModel, _ s: Sprite, _ x: Int, _ y: Int, flip: Bool, hide: Bool) {
        if let a = s.anchor, !m.s.hat.isEmpty, !hide {
            let hat = Art.sprite("hats/\(m.s.hat)_\(m.s.stage)")
            let ax = flip ? s.width - 1 - a.x : a.x
            st.draw(hat, x + ax - hat.width / 2, y + a.y + Int((Double(hat.height) * 0.35).rounded()) - hat.height)
        }
        if m.s.aura {
            let spark = Art.crow("st_spark")
            let w = Double(s.width), h = Double(s.height)
            let points: [(Double, Double)] = [(-6, 0.2), (w - 4, 0.1), (-10, 0.6), (w + 2, 0.55), (w * 0.4, -0.02)]
            for (i, p) in points.enumerated() where (m.frame + i * 3) % 10 < 4 {
                st.draw(spark, max(2, min(178, x + Int(p.0))), max(30, y + Int(h * p.1)))
            }
        }
    }

    static func draw(_ st: Stage, model m: GameModel) {
        let f = m.frame, G = ground, s = m.s
        let adult = s.stage == "adult", teen = s.stage == "teen"
        func top(_ r: Sprite, _ lift: Int = 0) -> Int { G - r.height + 1 - lift }
        func mid(_ r: Sprite) -> Int { (screenW - r.width) / 2 }
        func put(_ r: Sprite, _ x: Int, flip: Bool = false, lift: Int = 0, hide: Bool = false) {
            st.draw(r, x, top(r, lift), flip: flip)
            wear(st, m, r, x, top(r, lift), flip: flip, hide: hide)
        }
        func background(_ key: String) { st.draw(Art.sprite("bgs/" + key), 0, 0) }
        let nest = m.nestSprite()
        func homeBackground() {
            background("bg_out")
            for (id, art, x) in [("deco_flower", "flower", 6), ("deco_mush", "mush", 38), ("deco_grass", "grass", 70)] where s.owned.contains(id) {
                st.draw(Art.crow(art), x, G - 24)
            }
            let nx = 192 - nest.width
            st.draw(nest, nx, G - nest.height + 4)
            let shown = s.display.filter { (s.inv[$0] ?? 0) > 0 }.prefix(4)
            for (i, id) in shown.enumerated() {
                let item = Art.sprite("items/" + id)
                if let cg = item.image {
                    st.draw(cg, max(4, nx - 72) + i * 18, G + 2 - item.height / 2, item.width / 2, item.height / 2)
                }
            }
        }
        func middleNest() { background("bg_out"); st.draw(nest, mid(nest), G - nest.height + 4) }

        if s.stage == "egg" {
            middleNest()
            let t = s.eggTime
            let egg = Art.crow(t > 6 ? "egg0" : t > 4.5 ? (f % 4 < 2 ? "egg1" : "egg2") : t > 3 ? "egg3" : t > 1.2 ? "egg4" : "egg5")
            st.draw(egg, mid(egg), top(egg, 13))
            return
        }
        let front = Art.crow(s.stage + "_front")
        if s.awayUntil != nil || (s.focusEnd != nil && s.stage != "baby") {
            middleNest()
            if s.awayUntil != nil { let feather = Art.crow("feather"); st.draw(feather, 85, top(feather, 22)) }
            return
        }
        if let r = m.rub {
            let moving = now() - r.movedAt < 0.25
            if r.type == "wash" {
                background("bg_bath")
                let base = m.pose("bath", 0)
                put(moving ? m.pose("bath", f % 3) : base, mid(base))
                if moving, let p = r.pointer {
                    for i in 0..<3 {
                        st.draw(Art.crow("st_drop"), Int(p.x) - 8 + (f + i * 7) % 22 - 11, Int(p.y) - 10 + (f * 3 + i * 11) % 18 - 9)
                    }
                }
            } else {
                homeBackground()
                let x = mid(front)
                put(moving ? (teen ? front : m.pose("blinkF")) : front, x, lift: moving && f % 2 == 1 ? 1 : 0)
                if moving { st.draw(Art.crow("st_heart"), min(176, x + front.width), G - front.height + (f % 4 < 2 ? 0 : 3)) }
                if let p = r.pointer { st.draw(Art.crow("ic_pet"), Int(p.x) - 14, Int(p.y) - 14) }
            }
            return
        }
        if let act = s.act {
            background("bg_out")
            if act.type == "read" {
                put(front, mid(front))
                let book = Art.sprite(act.genre.map { "hats/book_\($0)" } ?? "hats/book")
                st.draw(book, (screenW - book.width) / 2, G - 22 - (f / 8) % 2)
                if let g = Catalog.genre(act.genre), !g.mark.isEmpty, f % 12 < 6 {
                    st.draw(Art.sprite(g.mark), min(176, mid(front) + front.width + 2), G - front.height + (f % 24 < 12 ? 4 : 0))
                }
            } else {
                let w = m.pose("walk", f % 3)
                let x = Int(50 + 60 * (0.5 + 0.5 * sin(Double(f) / 30)))
                put(w, min(196 - w.width, x), flip: cos(Double(f) / 30) < 0)
            }
            return
        }
        if s.sleeping || s.breakEnd != nil || s.focusEnd != nil {
            background("bg_sleep")
            let sl = m.pose("sleep", (f / 4) % 3)
            put(sl, mid(sl))
            if s.breakEnd != nil { st.draw(Art.crow("st_heart"), 24, 112) }
            return
        }
        homeBackground()
        var x = m.x
        var rows = front
        var flip = false
        var hide = false
        let slow = (f / 3) % 2
        let a = m.anim
        let angry = adult ? Art.crow("a_angry\(f % 2)") : Art.crow(s.stage + "_angry")
        if a == "bread" { rows = m.pose("eat", f % 6 < 2 ? 0 : f % 6 < 4 ? 1 : 2) }
        else if a == "joy" || a == "evolve" {
            rows = m.pose("happy", f % 2)
            if a == "evolve" { st.draw(Art.crow("st_spark"), max(2, x - 22), 132) }
        }
        else if a == "no" { rows = angry; x += f % 2 == 1 ? 2 : -2 }
        else if a == "cure" {
            st.draw(Art.sprite("misc/syringe"), min(170, x + rows.width), G - rows.height + 14)
            st.draw(Art.crow("st_spark"), max(2, x - 22), G - rows.height + 8)
        }
        else if s.sick { rows = s.stage == "baby" ? Art.crow("baby_sick") : m.pose("sick", slow) }
        else if s.hunger < 25 { rows = m.pose("hungry", slow) }
        else if s.clean < 25 { rows = m.pose("dirty", slow) }
        else if s.energy < 20 { rows = m.pose("sleepy", slow) }
        else if s.happy < 25 { rows = m.pose("sad", slow) }
        else if m.walking { rows = m.pose("walk", f % 3); flip = m.left }
        else if !m.front {
            if teen { rows = f % 17 == 0 ? Art.crow("t_blink1") : Art.crow("t_idle\(slow)") }
            else { rows = f % 17 == 0 ? m.pose("blinkS") : m.pose("idleS") }
            flip = m.left
        } else if !teen && f % 17 == 0 { rows = m.pose("blinkF") }

        if m.greetTimer > 0 && a.isEmpty && m.calm {
            rows = m.pose("happy", 1)
            st.draw(Art.crow("st_heart"), min(176, x + rows.width - 10), max(50, G - rows.height - 14))
        } else if a.isEmpty && !s.sick && s.happy >= 50 && s.hunger >= 25 && s.energy >= 20 && s.clean >= 25 && !m.walking {
            if s.sets.contains("rare") && f % 96 < 8 { rows = m.pose("happy", 1) }
            else if s.sets.contains("common") && f % 64 < 8 { rows = m.pose("happy", 0) }
        }
        x = max(2, min(x, 196 - rows.width))
        put(rows, x, flip: flip, hide: hide)
        hide = false
        if s.sick && a.isEmpty {
            let skull = Art.crow("st_skull")
            st.draw(skull, min(196 - skull.width, x + rows.width - 6), max(44, G - rows.height - skull.height + 3))
        }
        if a.isEmpty && (m.bubble == "heart" || m.bubble == "hearts") {
            st.draw(Art.crow("st_heart"), min(176, x + rows.width), max(50, G - rows.height))
        }
        if s.sets.contains("valley") && f % 32 < 4 { st.draw(Art.crow("st_spark"), min(178, x + rows.width - 6), G - rows.height + 12) }
        if adult && (s.inv["ring"] ?? 0) > 0 && f % 8 < 4 { st.draw(Art.crow("st_spark"), max(2, x - 18), G - rows.height) }
    }

    // MARK: 미니게임

    static func drawWorm(_ st: Stage, _ g: WormGame) {
        let n = now()
        st.fill(Palette.lcd, 0, 0, 198, 136)
        let soil = Art.sprite("misc/soil")
        var ty = 66
        while ty < 136 {
            var tx = -6
            while tx < 198 { st.draw(soil, tx, ty); tx += 60 }
            ty += 48
        }
        let crow = Art.crow("baby_side")
        st.draw(crow, 4 + (g.hop > 0 ? 1 : 0), 68 - crow.height - (g.hop > 2 ? 4 : 0))
        for (i, h) in GameModel.holes.enumerated() {
            st.draw(Art.sprite("misc/hole"), Int(h.x) - 19, Int(h.y) - 24)
            guard let slot = g.slots[i] else { continue }
            if slot.type == "wasp" {
                let wing = Int(n * 14) % 2 == 0 ? "misc/wasp0" : "misc/wasp1"
                st.draw(Art.sprite(wing), Int(h.x) - 17, Int(h.y) - 36 - (Int(n * 7) % 2) * 2)
                continue
            }
            let art = Art.sprite(slot.type == "fat" ? "misc/fat" : "misc/gw")
            let f = min(1, min(n - slot.born, slot.until - n) / 0.11)
            let visible = max(1, Int((Double(art.height) * f).rounded()))
            if let cg = art.topSlice(rows: visible) {
                st.draw(cg, Int(h.x) - art.width / 2, Int(h.y) - visible, art.width, visible)
            }
        }
        for fx in g.fx {
            if fx.spark { st.draw(Art.crow("st_spark"), Int(fx.x) - 30, Int(fx.y) + 2) }
            let rise = (fx.until - n) / 0.06 - 9
            let point = CGPoint(x: st.ox + CGFloat(fx.x + 6) * st.unit, y: st.oy + CGFloat(fx.y - rise) * st.unit)
            st.context.draw(Text(fx.text).font(.system(size: 13, weight: .bold)).foregroundColor(Palette.ink), at: point)
        }
    }

    static func drawShiny(_ st: Stage, _ g: ShinyGame) {
        let n = now()
        st.fill(Palette.lcd, 0, 0, 198, 136)
        func pos(_ i: Int) -> (Int, Int) { ((i % 4) * 49 + 25, (i / 4) * 45 + 23) }
        for (i, cell) in g.cells.enumerated() {
            var (cx, cy) = pos(i)
            if let sw = g.swap, sw.0 == i || sw.1 == i {
                let q = pos(sw.0 == i ? sw.1 : sw.0)
                let t = min(1, (n - g.swapStart) / max(0.01, g.swapEnd - g.swapStart))
                cx += Int(Double(q.0 - cx) * t)
                cy += Int(Double(q.1 - cy) * t) - Int(sin(t * .pi) * 10)
            }
            let open = g.phase == "show" || g.found.contains(i) || g.phase == "dead"
            let wrong = g.wrong == i && n < g.wrongUntil
            let shake = wrong ? (Int(n * 20) % 2 == 0 ? 2 : -2) : 0
            if open, let id = cell {
                st.draw(Art.sprite("items/" + id), cx - 14, cy - 14)
                if g.found.contains(i) && Int(n * 5) % 2 == 1 { st.draw(Art.crow("st_spark"), cx + 6, cy - 20) }
            } else if wrong {
                st.draw(Art.sprite("items/stone"), cx - 14 + shake, cy - 14)
            } else if !(open && cell == nil) {
                st.draw(Art.sprite("misc/leaf"), cx - 22 + shake, cy - 15)
            } else {
                st.fill(Palette.mid, cx - 10, cy + 10, 20, 1)
            }
        }
        if g.phase == "wind" {
            let k = Int(n * 16)
            for w in 0..<8 { st.fill(Palette.ink.opacity(0.6), (k * 5 + w * 23) % 218 - 10, (w * 11 + 5) % 136, 15, 1) }
        }
    }
}
