#!/usr/bin/env swift
import AppKit

// 独立生成设计候选，不覆盖应用已采用的图标。
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let destination = root.appendingPathComponent("Design/Explorations/05-Refined")
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
        [Shape(path: "M278 268H478V468H278Z", fill: blocks[0]),
         Shape(path: "M278 528H478V728H278Z", fill: blocks[1]),
         Shape(path: "M538 528H738V728H538Z", fill: blocks[2]),
         Shape(path: "M568 436L748 256M592 256H748V412", stroke: arrow, width: 72)]
    }
}
let white = "FFFFFF"
let candidates = [
    Candidate(name: "A  黑块加大", detail: "白底 · 黑色方块 · 黄色箭头", background: white, blocks: [black, black, black], arrow: yellow)
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
// 在相同大小的底板上对照原稿，并显示真实的小尺寸图标。
try png(width: 1120, height: 830, to: destination.appendingPathComponent("Preview.png")) { context in
    context.setFillColor(color("F0F0EC"))
    context.fill(CGRect(x: 0, y: 0, width: 1120, height: 830))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    label("BetterOpen / A 方案细化", x: 54, y: 36, size: 34, bold: true)
    label("黑块边长增加 25% · 箭头保持原尺寸", x: 56, y: 88, size: 21, hex: "68685F")
    for x in [CGFloat(40), CGFloat(580)] {
        context.setFillColor(color("FFFFFF"))
        context.addPath(CGPath(roundedRect: CGRect(x: x, y: 146, width: 500, height: 480), cornerWidth: 24, cornerHeight: 24, transform: nil))
        context.fillPath()
    }
    let originalURL = root.appendingPathComponent("Design/Explorations/05-Colors/BetterOpen-05-A.png")
    let original = NSImage(contentsOf: originalURL)!
    original.draw(in: CGRect(x: 95, y: 158, width: 390, height: 390), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    draw(candidates[0], in: context, rect: CGRect(x: 635, y: 158, width: 390, height: 390))
    label("原版", x: 250, y: 556, size: 25, bold: true)
    label("黑块加大", x: 766, y: 556, size: 25, bold: true)
    label("小尺寸效果", x: 56, y: 669, size: 22, bold: true)
    for (index, size) in [32, 64, 128].enumerated() {
        let x = CGFloat(260 + index * 200)
        draw(candidates[0], in: context, rect: CGRect(x: x, y: 653, width: CGFloat(size), height: CGFloat(size)))
        label("\(size) px", x: x, y: 789, size: 16, hex: "68685F")
    }
    NSGraphicsContext.restoreGraphicsState()
}
print("已生成 A 方案黑块加大的 PNG、SVG 与对照预览。")
