#!/usr/bin/env swift
import AppKit

// 生成形状与配色候选，不覆盖应用已采用的图标。
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red / 255, green / 255, blue / 255, 1])!
}
var shapeIndex = 0
var triangle: Bool { shapeIndex == 4 }
struct Palette {
    let name: String
    let hex: [String]
    let eyes: String
}
func hexColor(_ hex: String) -> CGColor {
    let n = UInt32(hex, radix: 16)!
    return color(CGFloat((n >> 16) & 255), CGFloat((n >> 8) & 255), CGFloat(n & 255))
}
let palettes = [
    Palette(name: "暖橙 · 活力", hex: ["FF9F5E", "F77934", "E66428"], eyes: "16191B"),
    Palette(name: "钴蓝 · 效率", hex: ["7DAAFF", "497DE0", "315FC2"], eyes: "FFFFFF"),
    Palette(name: "青绿 · 清爽", hex: ["65D6BC", "28AC91", "18826F"], eyes: "FFFFFF"),
    Palette(name: "柔紫 · 灵感", hex: ["B5A0F5", "8D70DC", "7153BC"], eyes: "FFFFFF"),
    Palette(name: "金黄 · 轻快", hex: ["FFE58B", "F5CB4A", "DDAE27"], eyes: "16191B"),
    Palette(name: "石墨 · 克制", hex: ["45484A", "242729", "16191B"], eyes: "F5F5F3")
]
var palette = palettes[0]
var ink: CGColor { hexColor(palette.hex[2]) }
var eyeColor: CGColor { hexColor(palette.eyes) }

// 用平滑的周期轮廓生成花瓣与有机形状。
func organic(lobes: Int, amplitude: CGFloat, radius: CGFloat, rotation: CGFloat = -.pi / 2) -> CGPath {
    let points = (0..<120).map { i -> CGPoint in
        let a = CGFloat(i) * 2 * .pi / 120 + rotation
        let r = radius + amplitude * cos(CGFloat(lobes) * (a - rotation))
        return CGPoint(x: 512 + r * cos(a), y: 512 + r * sin(a))
    }
    let p = CGMutablePath()
    p.move(to: points[0])
    for i in 0..<points.count {
        let a = points[(i + 119) % 120], b = points[i], c = points[(i + 1) % 120], d = points[(i + 2) % 120]
        p.addCurve(to: c, control1: CGPoint(x: b.x + (c.x-a.x)/6, y: b.y + (c.y-a.y)/6),
                   control2: CGPoint(x: c.x - (d.x-b.x)/6, y: c.y - (d.y-b.y)/6))
    }
    p.closeSubpath()
    return p
}

// 圆形保留原有轮廓，三角形使用圆角顶点与底角。
func bodyPath() -> CGPath {
    switch shapeIndex {
    case 0: return CGPath(ellipseIn: CGRect(x: 64, y: 64, width: 896, height: 896), transform: nil)
    case 1: return organic(lobes: 4, amplitude: 73, radius: 375, rotation: -.pi / 4)
    case 2:
        let p = CGMutablePath()
        for i in 0..<24 {
            let a = CGFloat(i) * .pi / 12 - .pi / 2
            let r: CGFloat = i.isMultiple(of: 2) ? 448 : 355
            let v = CGPoint(x: 512 + r*cos(a), y: 512 + r*sin(a))
            if i == 0 { p.move(to: v) } else { p.addLine(to: v) }
        }
        p.closeSubpath()
        return p
    case 3: return organic(lobes: 5, amplitude: 50, radius: 398)
    case 5: return CGPath(roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896), cornerWidth: 235, cornerHeight: 235, transform: nil)
    case 6: return organic(lobes: 3, amplitude: 42, radius: 401, rotation: -.pi / 3)
    case 7:
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 140, y: 520))
        p.addCurve(to: CGPoint(x: 884, y: 520), control1: CGPoint(x: 140, y: -80), control2: CGPoint(x: 884, y: -80))
        p.addLine(to: CGPoint(x: 884, y: 860))
        p.addQuadCurve(to: CGPoint(x: 800, y: 910), control: CGPoint(x: 884, y: 960))
        p.addLine(to: CGPoint(x: 690, y: 840))
        p.addQuadCurve(to: CGPoint(x: 610, y: 924), control: CGPoint(x: 690, y: 980))
        p.addLine(to: CGPoint(x: 490, y: 850))
        p.addQuadCurve(to: CGPoint(x: 370, y: 925), control: CGPoint(x: 450, y: 990))
        p.addLine(to: CGPoint(x: 235, y: 850))
        p.addQuadCurve(to: CGPoint(x: 140, y: 730), control: CGPoint(x: 140, y: 815))
        p.closeSubpath()
        return p
    default: break
    }
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
                            colors: palette.hex.map(hexColor) as CFArray,
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
    let sampling = 2
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



let destination = root.appendingPathComponent("Design/Explorations/08-Shapes-Palettes")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let names = ["圆形 · 已选主方向", "四叶形", "太阳形", "五瓣花", "圆角三角形", "圆角方形", "有机软团", "小幽灵"]
let details = ["简洁、亲和，小尺寸稳定", "灵动，有较强角色感", "醒目，但轮廓较繁复", "柔和，偏生活与陪伴", "有个性，略带警示联想", "规整，但与外底板相似", "自然随性，工具感较弱", "可爱，但角色联想较强"]
func svgPath(_ path: CGPath) -> String {
    var parts: [String] = []
    func xy(_ p: CGPoint) -> String { String(format: "%.3f %.3f", Double(p.x), Double(p.y)) }
    path.applyWithBlock { ptr in
        let e = ptr.pointee
        switch e.type {
        case .moveToPoint: parts.append("M" + xy(e.points[0]))
        case .addLineToPoint: parts.append("L" + xy(e.points[0]))
        case .addQuadCurveToPoint: parts.append("Q" + xy(e.points[0]) + " " + xy(e.points[1]))
        case .addCurveToPoint: parts.append("C" + xy(e.points[0]) + " " + xy(e.points[1]) + " " + xy(e.points[2]))
        case .closeSubpath: parts.append("Z")
        @unknown default: break
        }
    }
    return parts.joined()
}
func save(_ filename: String) throws {
    try writePNG(width: 1024, height: 1024, to: destination.appendingPathComponent(filename + ".png")) { drawIcon($0) }
    let eyes = eyeRects().map { "<rect x=\"\($0.minX)\" y=\"\($0.minY)\" width=\"\($0.width)\" height=\"\($0.height)\" rx=\"51\"/>" }.joined()
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="BetterOpen \(names[shapeIndex]) · \(palette.name)">
    <defs><radialGradient id="body" cx="380" cy="340" r="610" gradientUnits="userSpaceOnUse"><stop stop-color="#\(palette.hex[0])"/><stop offset="0.48" stop-color="#\(palette.hex[1])"/><stop offset="1" stop-color="#\(palette.hex[2])"/></radialGradient></defs>
    <path d="M512 64C920 64 960 104 960 512S920 960 512 960S64 920 64 512S104 64 512 64Z" fill="#FFFFFF"/>
    <g transform="translate(112.64 112.64) scale(0.78)"><path d="\(svgPath(bodyPath()))" fill="url(#body)"/><g fill="#\(palette.eyes)">\(eyes)</g></g></svg>
    """
    try svg.write(to: destination.appendingPathComponent(filename + ".svg"), atomically: true, encoding: .utf8)
}
func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false) {
    (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular), .foregroundColor: NSColor(calibratedWhite: 0.16, alpha: 1)])
}
func icon(_ c: CGContext, x: CGFloat, y: CGFloat, size: CGFloat) {
    c.saveGState(); c.translateBy(x: x, y: y); c.scaleBy(x: size / 1024, y: size / 1024)
    drawIcon(c); c.restoreGState()
}
for i in names.indices { shapeIndex = i; try save("Shape-\(i+1)") }
shapeIndex = 0
for i in palettes.indices { palette = palettes[i]; try save("Circle-Color-\(i+1)") }
func board(_ filename: String, width: Int, height: Int, draw: (CGContext) -> Void) throws {
    try writePNG(width: width, height: height, to: destination.appendingPathComponent(filename)) { c in
        c.setFillColor(color(239, 240, 242)); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: true)
        draw(c); NSGraphicsContext.restoreGraphicsState()
    }
}
try board("Shapes.png", width: 1600, height: 1130) { c in
    label("BetterOpen · 8 种形状", x: 48, y: 32, size: 32, bold: true)
    label("统一用暖橙比较轮廓 · 保留白底与双眼 · 圆形为已选主方向", x: 50, y: 84, size: 20)
    palette = palettes[0]
    for i in names.indices {
        shapeIndex = i
        let x = CGFloat(30 + (i % 4) * 395), y = CGFloat(140 + (i / 4) * 485)
        icon(c, x: x+25, y: y, size: 320)
        label("\(i+1)  \(names[i])", x: x+35, y: y+330, size: 22, bold: true)
        label(details[i], x: x+35, y: y+368, size: 17)
        for (j, size) in [32, 64].enumerated() { icon(c, x: x+115+CGFloat(j*90), y: y+408-CGFloat(size)/2, size: CGFloat(size)) }
    }
}
try board("Colors.png", width: 1440, height: 1140) { c in
    label("BetterOpen · 圆形配色对比", x: 48, y: 32, size: 32, bold: true)
    label("同一轮廓与双眼比例 · 暖橙更亲和，钴蓝更偏效率工具", x: 50, y: 84, size: 20)
    shapeIndex = 0
    for i in palettes.indices {
        palette = palettes[i]
        let x = CGFloat(40 + (i % 3) * 470), y = CGFloat(140 + (i / 3) * 495)
        icon(c, x: x+50, y: y, size: 340)
        label("\(i+1)  \(palette.name)", x: x+75, y: y+350, size: 24, bold: true)
        label("主色 #\(palette.hex[1])", x: x+115, y: y+390, size: 17)
        for (j, size) in [32, 64].enumerated() { icon(c, x: x+145+CGFloat(j*90), y: y+441-CGFloat(size)/2, size: CGFloat(size)) }
    }
}
print("已生成 8 种形状、6 组圆形配色及两张对比图。")
