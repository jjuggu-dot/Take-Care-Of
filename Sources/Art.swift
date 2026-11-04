import SwiftUI
import CoreGraphics

/// 칸 단위 그림 한 장. 좌우 반전본도 함께 들고 있어요.
final class Sprite {
    let width: Int
    let height: Int
    let image: CGImage?
    let flipped: CGImage?
    let anchor: (x: Int, y: Int)?
    private let rows: [[UInt8]]

    init(rows raw: [String], anchor: (x: Int, y: Int)?) {
        rows = raw.map { Array($0.utf8) }
        height = rows.count
        width = rows.first?.count ?? 0
        self.anchor = anchor
        image = Sprite.render(rows, flip: false)
        flipped = Sprite.render(rows, flip: true)
    }

    private static func render(_ rows: [[UInt8]], flip: Bool) -> CGImage? {
        let h = rows.count
        let w = rows.first?.count ?? 0
        guard w > 0, h > 0 else { return nil }
        var data = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            let row = rows[y]
            for x in 0..<min(w, row.count) {
                guard let c = Sprite.palette[row[x]] else { continue }
                let px = flip ? w - 1 - x : x
                let i = (y * w + px) * 4
                data[i] = c.0; data[i + 1] = c.1; data[i + 2] = c.2; data[i + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private static let palette: [UInt8: (UInt8, UInt8, UInt8)] = [
        UInt8(ascii: "0"): (0xDB, 0xE6, 0xC8),
        UInt8(ascii: "4"): (0xA4, 0xB5, 0x90),
        UInt8(ascii: "1"): (0x7D, 0x8A, 0x6E),
        UInt8(ascii: "2"): (0x4E, 0x5A, 0x44),
        UInt8(ascii: "3"): (0x23, 0x2D, 0x1E),
        UInt8(ascii: "#"): (0x23, 0x2D, 0x1E)
    ]

    /// 위쪽 일부만 잘라 낸 이미지 (지렁이가 올라오는 장면용)
    func topSlice(rows count: Int) -> CGImage? {
        guard let image, count > 0 else { return nil }
        return image.cropping(to: CGRect(x: 0, y: 0, width: width, height: min(count, height)))
    }
}

enum Art {
    private struct File: Decodable {
        let sprites: [String: [String]]
        let anchor: [String: [Int]]
    }

    private static let file: File = {
        guard let url = Bundle.main.url(forResource: "art", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode(File.self, from: data) else {
            return File(sprites: [:], anchor: [:])
        }
        return parsed
    }()

    private static var cache: [String: Sprite] = [:]

    static func sprite(_ key: String) -> Sprite {
        if let found = cache[key] { return found }
        var anchor: (x: Int, y: Int)?
        if key.hasPrefix("crow/"), let a = file.anchor[String(key.dropFirst(5))], a.count == 2 {
            anchor = (a[0], a[1])
        }
        let made = Sprite(rows: file.sprites[key] ?? [], anchor: anchor)
        cache[key] = made
        return made
    }

    static func crow(_ key: String) -> Sprite { sprite("crow/" + key) }
}

enum Palette {
    static let lcd = Color(red: 0.71, green: 0.77, blue: 0.63)
    static let ink = Color(red: 0.14, green: 0.18, blue: 0.12)
    static let mid = Color(red: 0.49, green: 0.54, blue: 0.43)
    static let low = Color(red: 0.78, green: 0.25, blue: 0.18)
}

/// 메뉴에서 쓰는 픽셀 그림
struct PixelImage: View {
    let key: String
    var body: some View {
        if let cg = Art.sprite(key).image {
            Image(decorative: cg, scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Color.clear
        }
    }
}
