import re, json
L=json.load(open('literals.json'))
LOC=re.compile(r'(String\(localized:|LocalizedStringResource\(|LocalizedStringResource\s*=|\bText\(|\bButton\(|\bLabel\(|\bToggle\(|\bPicker\(|\bSection\(|\bTextField\(|\bSecureField\(|navigationTitle\(|\bTab\(|\bMenu\(|\bLink\(|\balert\(|confirmationDialog\(|accessibilityLabel\(|accessibilityHint\(|accessibilityValue\(|\bhelp\(|ContentUnavailableView\(|LabeledContent\(|\bStepper\(|ProgressView\(|ShareLink\(|accessibilityAction\(named:|\bbadge\(|DatePicker\(|PhotosPicker\(|\bSlider\(|prompt:|accessibilityInputLabels\(\[)\s*$')
NONUI_CTX=re.compile(r'(accessibilityIdentifier\(|systemName:|systemImage:|forKey:|Image\(|named:|Logger|print\(|fatalError\(|assert|precondition|UserDefaults|withExtension:|forResource:|ofType:|URL\(string:|appending(Path)?Component\(|pathExtension|NSPredicate|\.contains\(|hasPrefix\(|hasSuffix\(|DefaultsKey|identifier:|Notification\.Name\(|Keychain|service:|account:|queue|DispatchQueue\(label:|os_log|Font\.custom\(|\.custom\(|fontName|CIFilter\(name:|setValue\(|forKeyPath:|value\(forKey|kCIInput|UTType|matching:|replacingOccurrences\(of:|components\(separatedBy:|split\(separator:|format:|dateFormat|\bid:|\bcase\s+\w+\s*=|rawValue|scheme|host|queryItems|URLQueryItem\(name:|Logger\(|subsystem:|category:|\bkey:|serviceType|keychain|productID|Product\.products\(for:|decode|encode)\s*$')
def text(segs): return ''.join(s if t=='text' else '\\('+s+')' for t,s in segs)
loc=[];other=[]
for l in L:
    t=text(l['segs'])
    if LOC.search(l['ctx']) and 'verbatim:' not in l['ctx'][-12:]:
        loc.append(l); continue
    other.append(l)
json.dump(loc,open('loc.json','w'),ensure_ascii=False)
cand=[]
for l in other:
    t=text(l['segs'])
    f=l['file']
    if f.startswith('SupportFiles/Debug'): continue
    if not re.search(r'[A-Za-z]{2}',t): continue
    if re.fullmatch(r'[\w.\-/:%@#]+',t) and not re.search(r'[A-Z][a-z]',t) : continue   # identifiers
    if re.fullmatch(r'[a-z][\w]*(\.[\w\-]+)+',t): continue  # dotted identifiers / symbol names
    if NONUI_CTX.search(l['ctx']): continue
    cand.append(l)
print(len(loc),len(other),len(cand))
for l in cand:
    print(f"{l['file']}:{l['line']}: {text(l['segs'])!r}   <<{l['ctx'][-60:]}")
