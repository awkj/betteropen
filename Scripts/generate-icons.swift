#!/usr/bin/env swift
import AppKit

// 使用原生矢量绘制生成全部资源；无需安装绘图库。
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("betteropen/Assets.xcassets")
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red / 255, green / 255, blue / 255, 1])!
}
let ink = color(49, 95, 194)
let eyeColor = color(255, 255, 255)

// 圆形轮廓配合宽范围的明暗过渡，表现钴蓝色球体。
func bodyPath() -> CGPath {
    CGPath(ellipseIn: CGRect(x: 64, y: 64, width: 896, height: 896), transform: nil)
}

// Dock 与 SVG 共用双眼参数；菜单栏按实际显示尺寸补偿双眼大小和间距。
let eyeCenters: [CGFloat] = [418, 606]
let eyeCenterY: CGFloat = 492
let eyeWidth: CGFloat = 102
let eyeHeight: CGFloat = 312

func eyeRects(menu: Bool = false) -> [CGRect] {
    let width: CGFloat = menu ? 132 : eyeWidth
    let height: CGFloat = menu ? 360 : eyeHeight
    // 菜单栏球体直径为 18 点，每只眼睛向外移动 0.5 点，间隙总共增加 1 点。
    let outwardOffset: CGFloat = menu ? 896 / 36 : 0
    return eyeCenters.map { centerX in
        let adjustedCenterX = centerX + (centerX < 512 ? -outwardOffset : outwardOffset)
        return CGRect(x: adjustedCenterX - width / 2, y: eyeCenterY - height / 2,
               width: width, height: height)
    }
}

func addEyes(_ context: CGContext, menu: Bool = false) {
    for rect in eyeRects(menu: menu) {
        context.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width / 2,
                               cornerHeight: rect.width / 2, transform: nil))
    }
}

func drawIcon(_ context: CGContext) {
    // Dock 使用白色连续圆角底板；球体与双眼整体缩放，保留均匀留白。
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 16,
                      color: CGColor(gray: 0, alpha: 0.16))
    let plate = CGMutablePath()
    plate.move(to: CGPoint(x: 512, y: 64))
    plate.addCurve(to: CGPoint(x: 960, y: 512), control1: CGPoint(x: 920, y: 64), control2: CGPoint(x: 960, y: 104))
    plate.addCurve(to: CGPoint(x: 512, y: 960), control1: CGPoint(x: 960, y: 920), control2: CGPoint(x: 920, y: 960))
    plate.addCurve(to: CGPoint(x: 64, y: 512), control1: CGPoint(x: 104, y: 960), control2: CGPoint(x: 64, y: 920))
    plate.addCurve(to: CGPoint(x: 512, y: 64), control1: CGPoint(x: 64, y: 104), control2: CGPoint(x: 104, y: 64))
    plate.closeSubpath()
    context.addPath(plate)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.translateBy(x: 112.64, y: 112.64)
    context.scaleBy(x: 0.78, y: 0.78)
    // 只用柔和球面明暗塑形，保留干净的白色双眼。
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 18,
                      color: CGColor(gray: 0, alpha: 0.22))
    context.setFillColor(ink)
    context.addPath(bodyPath())
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(bodyPath())
    context.clip()
    let sphere = CGGradient(colorsSpace: colorSpace,
                            colors: [color(125, 170, 255), color(73, 125, 224), ink] as CFArray,
                            locations: [0, 0.48, 1])!
    context.drawRadialGradient(sphere, startCenter: CGPoint(x: 380, y: 340), startRadius: 0,
                               endCenter: CGPoint(x: 380, y: 340), endRadius: 610,
                               options: [.drawsAfterEndLocation])
    context.restoreGState()
    context.setFillColor(eyeColor)
    addEyes(context)
    context.fillPath()
    context.restoreGState()
}

func writePNG(width: Int, height: Int, to url: URL, draw: (CGContext) -> Void) throws {
    // 以浮点色深超采样再缩小，保留球面渐变和小尺寸边缘的平滑过渡。
    let sampling = 4
    let flags = CGImageAlphaInfo.premultipliedLast.rawValue
    let large = CGContext(data: nil, width: width * sampling, height: height * sampling,
                          bitsPerComponent: 32, bytesPerRow: 0, space: colorSpace,
                          bitmapInfo: flags | CGBitmapInfo.floatComponents.rawValue)!
    large.translateBy(x: 0, y: CGFloat(height * sampling))
    large.scaleBy(x: CGFloat(sampling), y: -CGFloat(sampling))
    draw(large)
    let output = CGContext(data: nil, width: width, height: height,
                           bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: flags)!
    output.interpolationQuality = .high
    output.draw(large.makeImage()!, in: CGRect(x: 0, y: 0, width: width, height: height))
    let bitmap = NSBitmapImageRep(cgImage: output.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

let iconSet = assets.appendingPathComponent("AppIcon.appiconset")
var iconEntries: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let filename = "BetterOpen-\(size)@\(scale)x.png"
        try writePNG(width: pixels, height: pixels, to: iconSet.appendingPathComponent(filename)) { context in
            context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
            drawIcon(context)
        }
        iconEntries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
    }
}
try Data(contentsOf: iconSet.appendingPathComponent("BetterOpen-512@2x.png"))
    .write(to: root.appendingPathComponent("Design/Icon.png"))

let menuSet = assets.appendingPathComponent("menu-item.imageset")
var menuEntries: [[String: String]] = []
for scale in 1...3 {
    let filename = "BetterOpen-menu@\(scale)x.png"
    try writePNG(width: 20 * scale, height: 18 * scale, to: menuSet.appendingPathComponent(filename)) { context in
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        context.translateBy(x: 1, y: 0)
        context.scaleBy(x: 18 / 896, y: 18 / 896)
        context.translateBy(x: -64, y: -64)
        context.setFillColor(color(22, 25, 27))
        context.addPath(bodyPath())
        addEyes(context, menu: true)
        // 镂空双眼，随系统菜单栏的明暗模式自动适配。
        context.drawPath(using: .eoFill)
    }
    menuEntries.append(["idiom": "universal", "scale": "\(scale)x", "filename": filename])
}

func writeCatalog(_ entries: [[String: String]], to url: URL, template: Bool = false) throws {
    var catalog: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
    if template { catalog["properties"] = ["template-rendering-intent": "template"] }
    let data = try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url.appendingPathComponent("Contents.json"))
}
try writeCatalog(iconEntries, to: iconSet)
try writeCatalog(menuEntries, to: menuSet, template: true)

// SVG 与应用图标使用同一组几何参数和颜色，便于继续编辑。
let svgEyes = eyeRects().map { rect in
    "    <rect x=\"\(Int(rect.minX))\" y=\"\(Int(rect.minY))\" width=\"\(Int(rect.width))\" height=\"\(Int(rect.height))\" rx=\"\(Int(rect.width / 2))\"/>"
}.joined(separator: "\n")
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-labelledby="title">
  <title id="title">BetterOpen</title>
  <defs>
    <radialGradient id="sphere" cx="380" cy="340" r="610" gradientUnits="userSpaceOnUse">
      <stop stop-color="#7DAAFF"/>
      <stop offset="0.48" stop-color="#497DE0"/>
      <stop offset="1" stop-color="#315FC2"/>
    </radialGradient>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="125%" color-interpolation-filters="sRGB">
      <feDropShadow dx="0" dy="8" stdDeviation="9" flood-opacity="0.22"/>
    </filter>
    <filter id="plateShadow" x="-10%" y="-10%" width="120%" height="125%" color-interpolation-filters="sRGB">
      <feDropShadow dx="0" dy="8" stdDeviation="8" flood-opacity="0.16"/>
    </filter>
  </defs>
  <path d="M512 64C920 64 960 104 960 512S920 960 512 960S64 920 64 512S104 64 512 64Z" fill="#FFFFFF" filter="url(#plateShadow)"/>
  <g transform="translate(112.64 112.64) scale(0.78)">
  <circle cx="512" cy="512" r="448" fill="url(#sphere)" filter="url(#shadow)"/>
  <g fill="#FFFFFF">
\(svgEyes)
  </g>
  </g>
</svg>

"""

try svg.write(to: root.appendingPathComponent("Design/Icon.svg"), atomically: true, encoding: .utf8)
print("已生成 BetterOpen 应用图标、菜单栏模板图标与 SVG。")
