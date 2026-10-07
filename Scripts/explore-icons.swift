#!/usr/bin/env swift
import AppKit

// 独立生成设计候选，不覆盖应用已采用的图标。
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let destination = root.appendingPathComponent("Design/Explorations")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ hex: String) -> CGColor {
    let number = UInt32(hex, radix: 16)!
    return CGColor(colorSpace: space, components: [CGFloat((number >> 16) & 255) / 255,
        CGFloat((number >> 8) & 255) / 255, CGFloat(number & 255) / 255, 1])!
}
let yellow = "F9CA24"
let black = "171714"
struct Shape {
    let path: String
    var fill: String? = nil
    var stroke: String? = nil
    var width: CGFloat = 0
}
struct Candidate {
    let name: String
    let detail: String
    var inverted = false
    var whiteBackground = false
    let shapes: [Shape]
}
let candidates = [
    Candidate(name: "01  字母 B", detail: "品牌首字母 · 简洁、稳重", shapes: [
        Shape(path: "M292 248H536C670 248 746 310 746 398C746 452 720 486 674 506C735 526 768 567 768 628C768 723 690 776 546 776H292Z M404 346V456H527C597 456 630 438 630 401C630 364 597 346 527 346Z M404 556V678H538C616 678 650 659 650 617C650 575 616 556 538 556Z", fill: black),
        Shape(path: "M404 346V456H527C597 456 630 438 630 401C630 364 597 346 527 346Z", fill: "FFFFFF")
    ]),
    Candidate(name: "02  开口 O", detail: "打开 + 向外延伸 · 轻盈、直接", whiteBackground: true, shapes: [
        Shape(path: "M540 284H402C334 284 284 334 284 402V622C284 690 334 740 402 740H622C690 740 740 690 740 622V538", stroke: black, width: 80),
        Shape(path: "M548 476L740 284M596 284H740V428", stroke: yellow, width: 80)
    ]),
    Candidate(name: "03  双页展开", detail: "敞开的两扇门 · 对称、独特", shapes: [
        Shape(path: "M254 328L474 246V686L254 768Z", fill: black),
        Shape(path: "M550 246L770 328V768L550 686Z", fill: "FFFFFF")
    ]),
    Candidate(name: "04  快捷键", detail: "键帽 + 箭头 · 工具属性鲜明", inverted: true, shapes: [
        Shape(path: "M368 270H656C722 270 764 312 764 378V646C764 712 722 754 656 754H368C302 754 260 712 260 646V378C260 312 302 270 368 270Z", stroke: "FFFFFF", width: 72),
        Shape(path: "M370 512H644M538 406L644 512L538 618", stroke: yellow, width: 72)
    ]),
    Candidate(name: "05  跃出窗口", detail: "应用网格 + 启动 · 灵动、清晰", whiteBackground: true, shapes: [
        Shape(path: "M298 288H458V448H298Z M298 548H458V708H298Z M558 548H718V708H558Z", fill: black),
        Shape(path: "M568 436L748 256M592 256H748V412", stroke: yellow, width: 72)
    ]),
    Candidate(name: "06  BO 连字", detail: "B 与 O 相连 · 更强的品牌感", inverted: true, shapes: [
        Shape(path: "M394 300H430C502 300 550 348 550 420V604C550 676 502 724 430 724H394C322 724 274 676 274 604V420C274 348 322 300 394 300Z", stroke: yellow, width: 72),
        Shape(path: "M274 512H550", stroke: yellow, width: 64),
        Shape(path: "M594 300H630C702 300 750 348 750 420V604C750 676 702 724 630 724H594C522 724 474 676 474 604V420C474 348 522 300 594 300Z", stroke: "FFFFFF", width: 72)
    ])
]

// 候选的 SVG 路径同时用于位图渲染，保证预览和矢量源一致。
func path(_ source: String) -> CGPath {
    let regex = try! NSRegularExpression(pattern: "[MLCHVZ]|-?[0-9]+(?:\\.[0-9]+)?")
    let text = source as NSString
    let tokens = regex.matches(in: source, range: NSRange(location: 0, length: text.length)).map { text.substring(with: $0.range) }
    var index = 0
    var point = CGPoint.zero
    let result = CGMutablePath()
    func number() -> CGFloat { defer { index += 1 }; return CGFloat(Double(tokens[index])!) }
    func coordinate() -> CGPoint { CGPoint(x: number(), y: number()) }
    while index < tokens.count {
        let command = tokens[index]
        index += 1
        switch command {
        case "M": point = coordinate(); result.move(to: point)
        case "L": point = coordinate(); result.addLine(to: point)
        case "H": point.x = number(); result.addLine(to: point)
        case "V": point.y = number(); result.addLine(to: point)
        case "C": let a = coordinate(); let b = coordinate(); point = coordinate(); result.addCurve(to: point, control1: a, control2: b)
        case "Z": result.closeSubpath()
        default: fatalError("不支持的路径指令：\(command)")
        }
    }
    return result
}
func draw(_ candidate: Candidate, in context: CGContext, rect: CGRect) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.minY)
    context.scaleBy(x: rect.width / 1024, y: rect.height / 1024)
    context.setFillColor(color(candidate.inverted ? black : (candidate.whiteBackground ? "FFFFFF" : yellow)))
    context.addPath(CGPath(roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896), cornerWidth: 200, cornerHeight: 200, transform: nil))
    context.fillPath()
    for shape in candidate.shapes {
        context.addPath(path(shape.path))
        if let fill = shape.fill {
            context.setFillColor(color(fill))
            context.fillPath(using: .evenOdd)
        } else if let stroke = shape.stroke {
            context.setStrokeColor(color(stroke))
            context.setLineWidth(shape.width)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
        }
    }
    context.restoreGState()
}
func png(width: Int, height: Int, to url: URL, render: (CGContext) -> Void) throws {
    let context = CGContext(data: nil, width: width * 2, height: height * 2, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(height * 2))
    context.scaleBy(x: 2, y: -2)
    render(context)
    let output = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    output.interpolationQuality = .high
    output.draw(context.makeImage()!, in: CGRect(x: 0, y: 0, width: width, height: height))
    try NSBitmapImageRep(cgImage: output.makeImage()!).representation(using: .png, properties: [:])!.write(to: url)
}
for (index, candidate) in candidates.enumerated() {
    let filename = String(format: "BetterOpen-%02d", index + 1)
    try png(width: 1024, height: 1024, to: destination.appendingPathComponent(filename + ".png")) { context in
        draw(candidate, in: context, rect: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    }
    let elements = candidate.shapes.map { shape in
        if let fill = shape.fill { return "<path d=\"\(shape.path)\" fill=\"#\(fill)\" fill-rule=\"evenodd\"/>" }
        return "<path d=\"\(shape.path)\" fill=\"none\" stroke=\"#\(shape.stroke!)\" stroke-width=\"\(shape.width)\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
    }.joined(separator: "\n")
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="BetterOpen \(index + 1)">
    <rect x="64" y="64" width="896" height="896" rx="200" fill="#\(candidate.inverted ? black : (candidate.whiteBackground ? "FFFFFF" : yellow))"/>
    \(elements)
    </svg>
    """
    try svg.write(to: destination.appendingPathComponent(filename + ".svg"), atomically: true, encoding: .utf8)
}

func label(_ string: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false, hex: String = "171714") {
    let font = bold ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size)
    (string as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: NSColor(cgColor: color(hex))!])
}
try png(width: 1500, height: 1250, to: destination.appendingPathComponent("Comparison.png")) { context in
    context.setFillColor(color("F3F2ED"))
    context.fill(CGRect(x: 0, y: 0, width: 1500, height: 1250))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    label("BetterOpen", x: 70, y: 40, size: 42, bold: true)
    label("六个新方向 / 黑 · 黄 · 白", x: 72, y: 99, size: 23, hex: "68685F")
    for (index, candidate) in candidates.enumerated() {
        let x = CGFloat(index % 3) * 470 + 60
        let y = CGFloat(index / 3) * 525 + 166
        context.setFillColor(color("FFFFFF"))
        context.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: 440, height: 497), cornerWidth: 24, cornerHeight: 24, transform: nil))
        context.fillPath()
        draw(candidate, in: context, rect: CGRect(x: x + 58, y: y + 14, width: 324, height: 324))
        label(candidate.name, x: x + 28, y: y + 340, size: 27, bold: true)
        label(candidate.detail, x: x + 28, y: y + 381, size: 19, hex: "73736B")
        label("小尺寸", x: x + 28, y: y + 444, size: 16, hex: "8A8A82")
        draw(candidate, in: context, rect: CGRect(x: x + 102, y: y + 428, width: 40, height: 40))
        draw(candidate, in: context, rect: CGRect(x: x + 154, y: y + 422, width: 52, height: 52))
    }
    NSGraphicsContext.restoreGraphicsState()
}
print("已生成 6 组 PNG / SVG 候选和对比图。")
