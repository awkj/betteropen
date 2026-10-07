#!/usr/bin/env swift
import AppKit

// 独立生成设计候选，不覆盖应用已采用的图标。
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let destination = root.appendingPathComponent("Design/Explorations/05-Colors")
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
    let background: String
    let blocks: [String]
    let arrow: String
    var shapes: [Shape] {
        [Shape(path: "M298 288H458V448H298Z", fill: blocks[0]),
         Shape(path: "M298 548H458V708H298Z", fill: blocks[1]),
         Shape(path: "M558 548H718V708H558Z", fill: blocks[2]),
         Shape(path: "M568 436L748 256M592 256H748V412", stroke: arrow, width: 72)]
    }
}
let white = "FFFFFF"
let candidates = [
    Candidate(name: "A  白底 · 黄箭头", detail: "原方案 / 清爽、轻盈", background: white, blocks: [black, black, black], arrow: yellow),
    Candidate(name: "B  黑底 · 黄箭头", detail: "白色方块 / 对比鲜明", background: black, blocks: [white, white, white], arrow: yellow),
    Candidate(name: "C  黄底 · 白箭头", detail: "黑色方块 / 明亮、醒目", background: yellow, blocks: [black, black, black], arrow: white),
    Candidate(name: "D  黄底 · 黑箭头", detail: "白色方块 / 箭头更突出", background: yellow, blocks: [white, white, white], arrow: black),
    Candidate(name: "E  黑底 · 白箭头", detail: "黄色方块 / 沉稳、有力量", background: black, blocks: [yellow, yellow, yellow], arrow: white),
    Candidate(name: "F  白底 · 黑箭头", detail: "黄色方块 / 温暖、简洁", background: white, blocks: [yellow, yellow, yellow], arrow: black),
    Candidate(name: "G  黑底 · 双色方块", detail: "黄白交错 / 活泼、有节奏", background: black, blocks: [white, yellow, white], arrow: yellow),
    Candidate(name: "H  白底 · 单块点黄", detail: "黑白为主 / 黄色轻点缀", background: white, blocks: [black, black, yellow], arrow: black)
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
    context.setFillColor(color(candidate.background))
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
    let filename = "BetterOpen-05-" + String(UnicodeScalar(65 + index)!)
    try png(width: 1024, height: 1024, to: destination.appendingPathComponent(filename + ".png")) { context in
        draw(candidate, in: context, rect: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    }
    let elements = candidate.shapes.map { shape in
        if let fill = shape.fill { return "<path d=\"\(shape.path)\" fill=\"#\(fill)\" fill-rule=\"evenodd\"/>" }
        return "<path d=\"\(shape.path)\" fill=\"none\" stroke=\"#\(shape.stroke!)\" stroke-width=\"\(shape.width)\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
    }.joined(separator: "\n")
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="BetterOpen \(index + 1)">
    <rect x="64" y="64" width="896" height="896" rx="200" fill="#\(candidate.background)"/>
    \(elements)
    </svg>
    """
    try svg.write(to: destination.appendingPathComponent(filename + ".svg"), atomically: true, encoding: .utf8)
}

func label(_ string: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false, hex: String = "171714") {
    let font = bold ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size)
    (string as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: NSColor(cgColor: color(hex))!])
}
try png(width: 2000, height: 1240, to: destination.appendingPathComponent("Comparison.png")) { context in
    context.setFillColor(color("F3F2ED"))
    context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1240))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    label("BetterOpen / 05 配色探索", x: 70, y: 40, size: 42, bold: true)
    label("同一个图形，八种黑黄白组合", x: 72, y: 99, size: 23, hex: "68685F")
    for (index, candidate) in candidates.enumerated() {
        let x = CGFloat(index % 4) * 480 + 60
        let y = CGFloat(index / 4) * 525 + 166
        context.setFillColor(color("FFFFFF"))
        context.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: 450, height: 497), cornerWidth: 24, cornerHeight: 24, transform: nil))
        context.fillPath()
        draw(candidate, in: context, rect: CGRect(x: x + 63, y: y + 14, width: 324, height: 324))
        label(candidate.name, x: x + 28, y: y + 340, size: 24, bold: true)
        label(candidate.detail, x: x + 28, y: y + 381, size: 19, hex: "73736B")
        label("小尺寸", x: x + 28, y: y + 444, size: 16, hex: "8A8A82")
        draw(candidate, in: context, rect: CGRect(x: x + 102, y: y + 428, width: 40, height: 40))
        draw(candidate, in: context, rect: CGRect(x: x + 154, y: y + 422, width: 52, height: 52))
    }
    NSGraphicsContext.restoreGraphicsState()
}
print("已生成 05 的 8 组配色候选、SVG 与对比图。")
