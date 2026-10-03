import re, json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from lex import lex, swift_files
ROOT='/home/user/CueStudio/Cue Studio'

LOC_CALLS = r'(?:String\(localized:|LocalizedStringResource\(|LocalizedStringResource\s*=|Text\(|Button\(|Label\(|Toggle\(|Picker\(|Section\(|TextField\(|SecureField\(|navigationTitle\(|Tab\(|Menu\(|Link\(|alert\(|confirmationDialog\(|accessibilityLabel\(|accessibilityHint\(|accessibilityValue\(|help\(|ContentUnavailableView\(|LabeledContent\(|Stepper\(|ProgressView\(|ShareLink\(|accessibilityAction\(named:|badge\(|DatePicker\(|PhotosPicker\(|PasteButton\(|ControlGroup\(|DisclosureGroup\(|GroupBox\(|Slider\(|searchable\(text:[^,]*,\s*prompt:|prompt:|accessibilityInputLabels\(\[)'
def context(src, start):
    return src[max(0,start-160):start]

def key_of(segs):
    return segs

res=[]
for f in sorted(swift_files(ROOT)):
    src=open(f).read()
    rel=f[len(ROOT)+1:]
    for lit in lex(src):
        ctx=context(src,lit['start'])
        c1=re.sub(r'\s+',' ',ctx)
        res.append(dict(file=rel,line=lit['line'],segs=lit['segs'],ctx=c1[-120:],raw=lit['raw'],multi=lit['multi'], after=re.sub(r'\s+',' ',src[lit['end']:lit['end']+40])))
json.dump(res,open('literals.json','w'),ensure_ascii=False,indent=0)
print(len(res))
