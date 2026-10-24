import Foundation
// Each stdin line, Traditional characters folded to Simplified (ICU Hant-Hans).
while let line = readLine(strippingNewline: true) {
    print(line.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? line)
}
