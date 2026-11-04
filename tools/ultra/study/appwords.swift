// Counts each study script's words the way the app does (`ReadTime.wordCount`, `WordSegmenter`): words between spaces, and in a script
// written without spaces (Japanese, Chinese, Thai…) the system dictionary's words, which read at about the same pace. Python splits on
// spaces, which counts a whole Japanese sentence as one word; blind.py and the reports read these counts instead when they exist.
//
//     swift tools/ultra/study/appwords.swift <study folder>     → <study folder>/appwords.json (job id → words)

import Foundation
import NaturalLanguage

func isUnspaced(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x3005...0x3007, 0x3040...0x30FF, 0x31F0...0x31FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0xFF66...0xFF9F,
         0x20000...0x2FA1F, 0x0E00...0x0E7F, 0x0E80...0x0EFF, 0x1000...0x109F, 0x1780...0x17FF:
        return true
    default:
        return false
    }
}

func segments(_ text: String, language: String) -> Int {
    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.string = text
    switch language {
    case "zh-CN": tokenizer.setLanguage(.simplifiedChinese)
    case "zh-TW": tokenizer.setLanguage(.traditionalChinese)
    default: tokenizer.setLanguage(NLLanguage(rawValue: String(language.prefix(2))))
    }
    return tokenizer.tokens(for: text.startIndex..<text.endIndex).count
}

func words(_ script: String, language: String) -> Int {
    // Cues in brackets ("[pause]") are not said.
    let spoken = script.replacingOccurrences(of: #"\[[^\]\n]{1,40}\]"#, with: " ", options: .regularExpression)
    guard spoken.unicodeScalars.contains(where: isUnspaced) else {
        return spoken.split(whereSeparator: { $0.isWhitespace }).filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }.count
    }
    var count = 0
    var run = ""
    for character in spoken {
        if character.isLetter || character.isNumber {
            run.append(character)
        } else if !run.isEmpty {
            count += segments(run, language: language)
            run = ""
        }
    }
    if !run.isEmpty { count += segments(run, language: language) }
    return count
}

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let out = folder.appendingPathComponent("out")
var counts: [String: Int] = [:]
for file in try FileManager.default.contentsOfDirectory(at: out, includingPropertiesForKeys: nil) where file.pathExtension == "json" {
    guard let record = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any],
          let script = record["script"] as? String,
          let job = record["job"] as? [String: Any], let id = job["id"] as? String,
          let item = job["case"] as? [String: Any], let language = item["language"] as? String
    else { continue }
    counts[id] = words(script, language: language)
}
let data = try JSONSerialization.data(withJSONObject: counts, options: [.prettyPrinted, .sortedKeys])
try data.write(to: folder.appendingPathComponent("appwords.json"))
print("\(counts.count) scripts counted in \(folder.appendingPathComponent("appwords.json").path)")
