import Foundation
import NaturalLanguage

func isUnspaced(_ s: Unicode.Scalar) -> Bool {
    switch s.value {
    case 0x3005...0x3007, 0x3040...0x30FF, 0x31F0...0x31FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0xFF66...0xFF9F,
         0x20000...0x2FA1F, 0x0E00...0x0E7F, 0x0E80...0x0EFF, 0x1000...0x109F, 0x1780...0x17FF: return true
    default: return false
    }
}
func words(_ text: String, _ lang: String) -> Int {
    let spoken = text.replacingOccurrences(of: #"\[[^\]\n]*\]"#, with: " ", options: .regularExpression)
    if spoken.unicodeScalars.contains(where: isUnspaced) {
        let t = NLTokenizer(unit: .word); t.string = spoken
        let code = String(lang.prefix(2))
        let map: [String: NLLanguage] = ["ja": .japanese, "zh": lang.contains("Hant") || lang.contains("TW") ? .traditionalChinese : .simplifiedChinese, "th": .thai]
        if let l = map[code] { t.setLanguage(l) }
        var n = 0
        t.enumerateTokens(in: spoken.startIndex..<spoken.endIndex) { _, _ in n += 1; return true }
        return n
    }
    return spoken.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
}
let args = CommandLine.arguments
let catalog = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[1]))) as! [String: Any]
let strings = catalog["strings"] as! [String: Any]
var totals: [String: (en: Int, other: Int, n: Int)] = [:]
for (key, value) in strings {
    guard !key.contains("%"), words(key, "en") >= 8, let entry = value as? [String: Any], let locs = entry["localizations"] as? [String: Any] else { continue }
    let en = words(key, "en")
    for (lang, loc) in locs {
        guard let unit = (loc as? [String: Any])?["stringUnit"] as? [String: Any], let v = unit["value"] as? String else { continue }
        var t = totals[lang] ?? (0, 0, 0)
        t.en += en; t.other += words(v, lang); t.n += 1
        totals[lang] = t
    }
}
var out: [String: Any] = [:]
out["catalog"] = totals.mapValues { ["ratio": Double($0.other) / Double($0.en), "strings": $0.n] }
let human = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[2]))) as! [String: Any]
var clips: [[String: Any]] = []
for s in human["samples"] as! [[String: Any]] {
    clips.append(["file": s["file"]!, "language": s["language"]!, "words": words(s["script"] as! String, s["language"] as! String), "seconds": s["seconds"]!])
}
out["clips"] = clips
let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys, .prettyPrinted])
FileManager.default.createFile(atPath: args[3], contents: data)
print("ok")
