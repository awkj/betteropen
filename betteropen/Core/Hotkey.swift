import Foundation

/// 直接存储系统键码和修饰键位图，不再解析旧版快捷键字符串。
nonisolated struct Hotkey: Codable, Equatable, Hashable, Sendable {
    let keyCode: Int
    let modifiers: Int

    var isValid: Bool {
        (0...127).contains(keyCode) && modifiers >= 0 && modifiers & ~6912 == 0
    }
}
