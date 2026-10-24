import Foundation
// Reads lines of Simplified Chinese on stdin, writes them in Traditional characters (ICU's Hans-Hant).
while let line = readLine() {
    print(line.applyingTransform(StringTransform(rawValue: "Hans-Hant"), reverse: false) ?? "FAILED")
}
