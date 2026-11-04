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

    func draw(_ s: Sprite, x: Double, y: Double, width: Double, height: Double) {
        guard let cg = s.image else { return }
        let rect = CGRect(x: ox + CGFloat(x) * unit, y: oy + CGFloat(y) * unit, width: CGFloat(width) * unit, height: CGFloat(height) * unit)
        context.draw(Image(decorative: cg, scale: 1).interpolation(.none), in: rect)
    }

    func fill(_ color: Color, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        let rect = CGRect(x: ox + CGFloat(x) * unit, y: oy + CGFloat(y) * unit, width: CGFloat(w) * unit, height: CGFloat(h) * unit)
        context.fill(Path(rect), with: .color(color))
    }

    func toLogical(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - ox) / unit, y: (p.y - oy) / unit) }
}

enum Scene {
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

    private static func period(_ h: Double) -> (sky: Color, shift: Int, night: Bool, stars: Int) {
        func c(_ r: Int, _ g: Int, _ b: Int) -> Color { Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }
        if h >= 4 && h < 6 { return (c(0x8E, 0x9C, 0x7E), 1, true, 3) }
        if h >= 6 && h < 11 { return (c(0xC4, 0xD2, 0xAF), 0, false, 0) }
        if h >= 11 && h < 16 { return (c(0xCF, 0xDC, 0xBB), 0, false, 0) }
        if h >= 16 && h < 19 { return (c(0xA4, 0xB5, 0x90), 1, false, 0) }
        if h >= 19 && h < 22 { return (c(0x5F, 0x6C, 0x53), 2, true, 2) }
        return (c(0x4E, 0x5A, 0x44), 2, true, 1)
    }

    private static func moonPhase() -> Double {
        let reference = Date(timeIntervalSince1970: 947182440) // 2000-01-06 18:14 UTC 신월
        let p = Date().timeIntervalSince(reference) / 86400 / 29.530588
        return p - floor(p)
    }

    private static func drawSky(_ st: Stage, _ m: GameModel) {
        let h = m.hourNow, per = period(h), t = now()
        st.fill(per.sky, -40, -40, 278, 322)
        let bright = Color(red: 0.86, green: 0.90, blue: 0.78)
        let dim = Color(red: 0.64, green: 0.71, blue: 0.56)
        if per.night {
            for i in 0..<46 where i % per.stars == 0 {
                let x = (i * 73 + 11) % 198, y = (i * 37 + 8 + (i * i) % 41) % 118 + 30
                let a = sin(t * 1.6 + Double(i) * 1.7)
                if a < -0.5 { continue }
                st.fill(a > 0.4 ? bright : dim, x, y, 1, 1)
                if a > 0.8 { st.fill(bright, x - 1, y, 3, 1); st.fill(bright, x, y - 1, 1, 3) }
            }
            let progress = ((h - 19 + 24).truncatingRemainder(dividingBy: 24)) / 11
            let mx = Int(progress * 210 - 6), my = Int(122 - 40 * sin(.pi * min(1, progress)))
            let phase = moonPhase(), c = cos(2 * .pi * phase), r = 12
            for y in -r...r {
                let half = (Double(r * r - y * y)).squareRoot()
                let span = Int(half.rounded())
                for x in -span...span where span > 0 || x == 0 {
                    let limit = half * c
                    let lit = phase < 0.5 ? Double(x) >= limit : Double(x) <= -limit
                    st.fill(lit ? bright : Palette.mid, mx + x, my + y, 1, 1)
                }
            }
        } else {
            let progress = (h - 6) / 13
            let sx = Int(progress * 210 - 6), sy = Int(124 - 40 * sin(.pi * progress))
            for y in -9...9 {
                let w = Int((Double(81 - y * y)).squareRoot().rounded())
                st.fill(bright, sx - w, sy + y, w * 2 + 1, 1)
            }
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4
                st.fill(dim, sx + Int(13 * cos(angle)) - 1, sy + Int(13 * sin(angle)) - 1, 3, 3)
            }
            for (key, y, speed, offset) in [("cl0", 44, 3.0, 0.0), ("cl2", 68, 2.0, 120.0), ("cl3", 96, 1.5, 200.0), ("cl1", 118, 4.0, 60.0)] {
                let x = (t * speed + offset).truncatingRemainder(dividingBy: 278) - 70
                st.draw(Art.crow(key), Int(x), y)
            }
        }
        st.draw(Art.tree(shift: per.shift), 0, 0)
    }

    static func draw(_ st: Stage, model m: GameModel) {
        let f = m.frame, s = m.s
        let G = m.groundY
        let adult = s.stage == "adult", teen = s.stage == "teen"
        let nest = m.nestSprite(), nx = m.nestX, nt = m.nestTop
        let rimRow = Int((Double(nest.height) * 0.4).rounded())
        func top(_ r: Sprite, _ lift: Int = 0) -> Int { G - r.height + 1 - lift }
        func mid(_ r: Sprite) -> Int { nx + (nest.width - r.width) / 2 }
        func put(_ r: Sprite, _ x: Int, flip: Bool = false, lift: Int = 0, hide: Bool = false) {
            st.draw(r, x, top(r, lift), flip: flip)
            wear(st, m, r, x, top(r, lift), flip: flip, hide: hide)
        }
        func background(_ key: String) { st.fill(Palette.lcd, -40, -40, 278, 322); st.draw(Art.sprite("bgs/" + key), 0, 0) }
        func scene() {
            drawSky(st, m)
            for (id, art, x, y) in [("deco_flower", "flower", 4, 146), ("deco_mush", "mush", 176, 138), ("deco_grass", "grass", 22, 132)] where s.owned.contains(id) {
                st.draw(Art.crow(art), x, y)
            }
            st.draw(nest, nx, nt)
        }
        func rim() {
            if let cg = nest.bottomSlice(from: rimRow) { st.draw(cg, nx, nt + rimRow, nest.width, nest.height - rimRow) }
            let shown = s.display.filter { (s.inv[$0] ?? 0) > 0 }.prefix(4)
            for (i, id) in shown.enumerated() {
                let item = Art.sprite("items/" + id)
                if let cg = item.image {
                    st.draw(cg, nx + 18 + i * 22, nt + nest.height - 26 - (i % 2) * 4, item.width / 2, item.height / 2)
                }
            }
        }

        if s.stage == "egg" {
            scene()
            let t = s.eggTime
            let egg = Art.crow(t > 6 ? "egg0" : t > 4.5 ? (f % 4 < 2 ? "egg1" : "egg2") : t > 3 ? "egg3" : t > 1.2 ? "egg4" : "egg5")
            st.draw(egg, mid(egg), top(egg, -6))
            rim()
            return
        }
        let front = Art.crow(s.stage + "_front")
        if s.awayUntil != nil || (s.focusEnd != nil && s.stage != "baby") {
            scene()
            if s.awayUntil != nil { st.draw(Art.crow("feather"), nx + 40, nt + 2) }
            rim()
            return
        }
        if let r = m.rub {
            let n = now()
            let moving = n - r.movedAt < 0.25
            if r.type == "wash" { background("bg_bath") } else { scene() }
            let eyes = moving && !teen ? m.pose("blinkF") : front
            let c = m.closeUp(front, at: n)
            let w = Double(front.width) * c.scale, h = Double(front.height) * c.scale
            st.draw(eyes, x: c.x, y: c.y - (moving && f % 2 == 1 ? 2 : 0), width: w, height: h)
            if let a = front.anchor, !s.hat.isEmpty {
                let hat = Art.sprite("hats/\(s.hat)_\(s.stage)")
                let hw = Double(hat.width) * c.scale, hh = Double(hat.height) * c.scale
                st.draw(hat, x: c.x + Double(a.x) * c.scale - hw / 2, y: c.y + Double(a.y) * c.scale + hh * 0.35 - hh, width: hw, height: hh)
            }
            let art = Art.crow(r.type == "wash" ? "st_drop" : "st_heart")
            for pop in r.pops {
                let age = n - pop.born
                let size = 0.7 + min(1, age / 0.3) * 0.9
                st.draw(art, x: pop.x + pop.drift * age - Double(art.width) * size / 2, y: pop.y - 58 * age - Double(art.height) * size / 2,
                        width: Double(art.width) * size, height: Double(art.height) * size)
            }
            return
        }
        if let act = s.act {
            if act.type == "read" {
                scene()
                put(front, mid(front))
                rim()
                let book = Art.sprite(act.genre.map { "hats/book_\($0)" } ?? "hats/book")
                st.draw(book, mid(book), nt + rimRow - 6 - (f / 8) % 2)
                if let g = Catalog.genre(act.genre), !g.mark.isEmpty, f % 12 < 6 {
                    st.draw(Art.sprite(g.mark), min(176, mid(front) + front.width + 2), G - front.height + (f % 24 < 12 ? 4 : 0))
                }
            } else {
                background("bg_out")
                let w = m.pose("walk", f % 3)
                let x = min(196 - w.width, Int(50 + 60 * (0.5 + 0.5 * sin(Double(f) / 30))))
                let flip = cos(Double(f) / 30) < 0
                st.draw(w, x, 198 - w.height + 1, flip: flip)
                wear(st, m, w, x, 198 - w.height + 1, flip: flip, hide: false)
            }
            return
        }
        if s.sleeping || s.breakEnd != nil || s.focusEnd != nil {
            scene()
            let sl = m.pose("sleep", (f / 4) % 3)
            put(sl, mid(sl), lift: -8)
            rim()
            if s.breakEnd != nil { st.draw(Art.crow("st_heart"), 24, 112) }
            return
        }
        scene()
        var x = m.x
        var rows = front
        var flip = false
        let slow = (f / 3) % 2
        let a = m.anim
        let angry = adult ? Art.crow("a_angry\(f % 2)") : Art.crow(s.stage + "_angry")
        if a == "bread" { rows = m.pose("eat", f % 6 < 2 ? 0 : f % 6 < 4 ? 1 : 2) }
        else if a == "joy" || a == "evolve" {
            rows = m.pose("happy", f % 2)
            if a == "evolve" { st.draw(Art.crow("st_spark"), max(2, x - 22), G - 60) }
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
        let low = nx + 2, high = max(low, nx + nest.width - 2 - rows.width)
        x = max(low, min(x, high))
        put(rows, x, flip: flip)
        rim()
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
