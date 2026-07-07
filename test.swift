import Foundation

let text = "Hello 👋 world! 123 ❤️"
let noEmoji = text.unicodeScalars.filter { scalar in
    if scalar.properties.isEmoji || scalar.properties.isEmojiPresentation || scalar.value == 0xFE0F {
        if scalar.value <= 127 { return true }
        return false
    }
    return true
}.map(String.init).joined()

print("No emoji: \(noEmoji)")
