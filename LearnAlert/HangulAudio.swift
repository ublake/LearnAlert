import Foundation

/// Bundled letter recordings; syllables and longer expressions keep Korean speech synthesis.
enum HangulAudio {
    static let vowels = Array("ㅏㅑㅓㅕㅗㅛㅜㅠㅡㅣㅐㅒㅔㅖㅘㅙㅚㅝㅞㅟㅢ").map(String.init)
    static let consonants = Array("ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃㅆㅉ").map(String.init)
    static func filename(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = vowels.firstIndex(of: trimmed) { return String(format: "vowel_%02d", index + 1) }
        if let index = consonants.firstIndex(of: trimmed) { return String(format: "consonant_%02d", index + 1) }
        // A standalone vowel block has exactly the same sound as its vowel.
        let blocks = Array("아야어여오요우유으이애얘에예와왜외워웨위의").map(String.init)
        if let index = blocks.firstIndex(of: trimmed) { return String(format: "vowel_%02d", index + 1) }
        return nil
    }
    static func url(for text: String) -> URL? {
        guard let filename = filename(for: text) else { return nil }
        return Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "hangulaudio")
            ?? Bundle.main.url(forResource: filename, withExtension: "mp3")
    }
}
