// アプリアイコン(1024x1024)を描く。使い方: swift tools/make-icon.swift App/Assets.xcassets/AppIcon.appiconset/icon-1024.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon-1024.png"
// App Store のアイコンは透明チャンネルを含められないので、alpha なし(noneSkipLast)のビットマップに描く
let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// 背景: 縦のグラデーション(フルブリードの正方形。角丸は iOS が付ける)
let colors = [CGColor(red: 0.13, green: 0.62, blue: 0.62, alpha: 1), CGColor(red: 0.05, green: 0.36, blue: 0.55, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

// 残量バー 3 本(上から 満タン・半分・残りわずか)。最後だけオレンジで「そろそろ」を表す
let barW: CGFloat = 640, barH: CGFloat = 116, gap: CGFloat = 70
let left = (size - barW) / 2
let top = (size - (barH * 3 + gap * 2)) / 2
let fills: [CGFloat] = [1.0, 0.55, 0.2]
for (i, f) in fills.enumerated() {
    let y = size - top - barH - CGFloat(i) * (barH + gap)
    let track = CGRect(x: left, y: y, width: barW, height: barH)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.28))
    ctx.addPath(CGPath(roundedRect: track, cornerWidth: barH / 2, cornerHeight: barH / 2, transform: nil)); ctx.fillPath()
    let fill = CGRect(x: left, y: y, width: max(barH, barW * f), height: barH)
    ctx.setFillColor(i == 2 ? CGColor(red: 1.0, green: 0.62, blue: 0.16, alpha: 1) : CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(CGPath(roundedRect: fill, cornerWidth: barH / 2, cornerHeight: barH / 2, transform: nil)); ctx.fillPath()
}
let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
precondition(CGImageDestinationFinalize(dest))
print("wrote \(out)")
