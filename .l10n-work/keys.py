import json,re
L=json.load(open('lits2.json'))
INT=set('''Int(ReadingLayout.recommendedFrontOffset)|Int(layout.lineOffset)|Int(offset)|Int(session.prompter.margin)|Int(session.prompter.textWindowHeight)|Int(viewModel.textSize)|ReadTime.wordCount(in: text)|UsagePolicy.freeExports|count|index|index + 1|left|limit|number|number + 1|percent|rawValue|script.version|script.version + 1|shownPauses.count|sure.count|takeCount|takes.count|takes.takes.count|timeline.segments.count|trialDays|type.structure.blocks.count|value|version|version + 1|video.takes.count|videos.count|viewModel.scriptTakes.count|whole|words|zone.words|document.wordCount|points|frameRate.rawValue|badge|whole / 60'''.split('|'))
def spec(expr, lit):
    e=expr.strip()
    if e in INT: return '%lld'
    if re.match(r'Int\(',e): return '%lld'
    return '%@'
def key(segs):
    out=''
    has_interp=any(t=='interp' for t,_ in segs)
    for t,s in segs:
        if t=='text': out+= s.replace('%','%%') if has_interp else s
        else:
            # specifier: handles "x, specifier: "%.1f""
            m=re.search(r',\s*specifier:\s*"([^"]+)"',s)
            if s.strip()=='$0':
                out+= '%lld' if 'days' in ''.join(x for t2,x in segs if t2=='text') else '%@'
            else:
                out+= m.group(1) if m else spec(s,None)
    return out
EXTRA_FUNCS={'tile','option','item','source','sourceLabel','OptionChipRow'}
keys={}
for l in L:
    ok = l['kind']=='loc'
    if not ok and l['enc'] and l['enc'][0] in EXTRA_FUNCS and l['enc'][1] in ('','title','detail'):
        ok=True
    if not ok: continue
    if l['file'].startswith('SupportFiles/Debug'): continue
    k=key(l['segs'])
    if '#Preview' in l.get('ctx',''): pass
    keys.setdefault(k,[]).append(f"{l['file']}:{l['line']}")
# manual extras
extras=["Cancel countdown","Record","Stop recording","2 minutes on how the electric shower was invented in Brazil","Describe your next video…",
 "Starts a new script from a prompt, a blank page or a document.","Opens the camera with the script ready to scroll under the lens.","Script",
 "Record script","New script"]
for e in extras: keys.setdefault(e,['manual'])
json.dump(keys,open('keys.json','w'),ensure_ascii=False,indent=0)
old=json.load(open('/home/user/CueStudio/Cue Studio/SupportFiles/Localizable.xcstrings'))['strings']
missing=[k for k in old if k not in keys]
print('keys',len(keys),'old',len(old),'old-not-found',len(missing))
for k in missing: print(repr(k))
