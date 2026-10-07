#!/usr/bin/env swift
import AppKit

// 独立生成两版橙色设计候选与对比图，不覆盖应用已采用的图标。
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("betteropen/Assets.xcassets")
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red / 255, green / 255, blue / 255, 1])!
}
var triangle = false
let ink = color(230, 100, 40)
let eyeColor = color(22, 25, 27)

// 圆形保留原有轮廓，三角形使用圆角顶点与底角。
func bodyPath() -> CGPath {
    if !triangle { return CGPath(ellipseIn: CGRect(x: 64, y: 64, width: 896, height: 896), transform: nil) }
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 512, y: 64))
    p.addCurve(to: CGPoint(x: 611, y: 132), control1: CGPoint(x: 552, y: 64), control2: CGPoint(x: 584, y: 87))
    p.addLine(to: CGPoint(x: 937, y: 777))
    p.addCurve(to: CGPoint(x: 838, y: 960), control1: CGPoint(x: 1000, y: 898), control2: CGPoint(x: 931, y: 960))
    p.addLine(to: CGPoint(x: 186, y: 960))
    p.addCurve(to: CGPoint(x: 87, y: 777), control1: CGPoint(x: 93, y: 960), control2: CGPoint(x: 24, y: 898))
    p.addLine(to: CGPoint(x: 413, y: 132))
    p.addCurve(to: CGPoint(x: 512, y: 64), control1: CGPoint(x: 440, y: 87), control2: CGPoint(x: 472, y: 64))
    p.closeSubpath()
    return p
}

// Dock 与 SVG 共用双眼参数；菜单栏按实际显示尺寸补偿双眼大小和间距。
let eyeCenters: [CGFloat] = [418, 606]
let eyeCenterY: CGFloat = 492
let eyeWidth: CGFloat = 102
let eyeHeight: CGFloat = 312

func eyeRects(menu: Bool = false) -> [CGRect] {
    let width: CGFloat = menu ? 132 : eyeWidth
    let height: CGFloat = triangle ? 185 : (menu ? 360 : eyeHeight)
    // 菜单栏球体直径为 18 点，每只眼睛向外移动 0.5 点，间隙总共增加 1 点。
    let outwardOffset: CGFloat = menu ? 896 / 36 : 0
    return eyeCenters.map { centerX in
        let adjustedCenterX = centerX + (centerX < 512 ? -outwardOffset : outwardOffset)
        return CGRect(x: adjustedCenterX - width / 2, y: (triangle ? 680 : eyeCenterY) - height / 2,
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
    // 使用柔和橙色渐变塑形，搭配深色双眼。
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
                            colors: [color(255, 159, 94), color(247, 121, 52), ink] as CFArray,
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


let destination = root.appendingPathComponent("Design/Explorations/07-Orange")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for variant in [true, false] {
    triangle = variant
    let filename = variant ? "A-Triangle" : "B-Circle"
    try writePNG(width: 1024, height: 1024, to: destination.appendingPathComponent(filename + ".png")) { drawIcon($0) }
    let body = variant
      ? "<path d=\"M512 64C552 64 584 87 611 132L937 777C1000 898 931 960 838 960H186C93 960 24 898 87 777L413 132C440 87 472 64 512 64Z\""
      : "<circle cx=\"512\" cy=\"512\" r=\"448\""
    let eyes = eyeRects().map { "<rect x=\"\($0.minX)\" y=\"\($0.minY)\" width=\"\($0.width)\" height=\"\($0.height)\" rx=\"51\"/>" }.joined()
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="BetterOpen \(variant ? "圆角三角形" : "圆形")橙色候选">
    <defs><radialGradient id="orange" cx="380" cy="340" r="610" gradientUnits="userSpaceOnUse"><stop stop-color="#FF9F5E"/><stop offset="0.48" stop-color="#F77934"/><stop offset="1" stop-color="#E66428"/></radialGradient></defs>
    <path d="M512 64C920 64 960 104 960 512S920 960 512 960S64 920 64 512S104 64 512 64Z" fill="#FFFFFF"/>
    <g transform="translate(112.64 112.64) scale(0.78)">
    \(body) fill="url(#orange)"/>
    <g fill="#16191B">\(eyes)</g></g></svg>
    """
    try svg.write(to: destination.appendingPathComponent(filename + ".svg"), atomically: true, encoding: .utf8)
}
func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false) {
    (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular), .foregroundColor: NSColor(calibratedWhite: 0.16, alpha: 1)])
}
try writePNG(width: 1440, height: 1050, to: destination.appendingPathComponent("Comparison.png")) { context in
    context.setFillColor(color(239, 240, 242))
    context.fill(CGRect(x: 0, y: 0, width: 1440, height: 1050))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    label("BetterOpen · 橙色方案对比", x: 60, y: 44, size: 32, bold: true)
    label("同一配色 · 白色底板 · 深色双眼", x: 62, y: 96, size: 20)
    for (index, variant) in [true, false].enumerated() {
        triangle = variant
        let x = CGFloat(60 + index * 700)
        context.saveGState()
        context.translateBy(x: x, y: 160)
        context.scaleBy(x: 600 / 1024, y: 600 / 1024)
        drawIcon(context)
        context.restoreGState()
        label(variant ? "A  圆角三角形" : "B  保留圆形", x: x + 175, y: 770, size: 26, bold: true)
        label(variant ? "轮廓更鲜明，双眼缩短并下移" : "保留原有比例，只替换配色", x: x + 132, y: 814, size: 19)
        for (i, size) in [32, 64, 128].enumerated() {
            context.saveGState()
            context.translateBy(x: x + 130 + CGFloat(i * 140), y: 892 - CGFloat(size) / 2)
            context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
            drawIcon(context)
            context.restoreGState()
            label("\(size) px", x: x + 125 + CGFloat(i * 140), y: 980, size: 16)
        }
    }
    NSGraphicsContext.restoreGraphicsState()
}
print("已生成橙色三角形、橙色圆形的 PNG、SVG 与对比图。")
