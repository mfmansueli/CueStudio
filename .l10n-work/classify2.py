import re, json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from lex import lex, swift_files
ROOT='/home/user/CueStudio/Cue Studio'
LOC_FUNCS={'Text':[''],'Button':[''],'Label':[''],'Toggle':[''],'Picker':[''],'Section':[''],'TextField':['','prompt'],'SecureField':[''],
 'navigationTitle':[''],'Tab':[''],'Menu':[''],'Link':[''],'alert':[''],'confirmationDialog':[''],'accessibilityLabel':[''],'accessibilityHint':[''],
 'accessibilityValue':[''],'help':[''],'ContentUnavailableView':['','description'],'LabeledContent':[''],'Stepper':[''],'ProgressView':[''],'ShareLink':[''],
 'accessibilityAction':['named'],'badge':[''],'DatePicker':[''],'PhotosPicker':[''],'Slider':[''],'searchable':['prompt'],'accessibilityInputLabels':[''],
 'navigationSubtitle':[''],'SearchField':['prompt'],'OptionChipRow':['title'],
 'localized':[], # handled separately
}
def enclosing(src, pos):
    """Return (funcname, label, between) for innermost open paren/bracket containing pos."""
    depth=0; i=pos-1; seg_start=pos
    while i>=0:
        ch=src[i]
        if ch in ')]}': depth+=1
        elif ch in '([{':
            if depth==0:
                opener=ch; break
            depth-=1
        elif ch=='"' :
            # skip back over string literal (approx): find previous quote
            j=src.rfind('"',0,i)
            i=j-1; continue
        i-=1
    else: return None
    # arg text from opener to pos at depth 0: find last top-level comma
    argtext=src[i+1:pos]
    d=0; last=0
    for k,ch in enumerate(argtext):
        if ch in '([{': d+=1
        elif ch in ')]}': d-=1
        elif ch==',' and d==0: last=k+1
    arg=argtext[last:].strip()
    m=re.match(r'(\w+)\s*:\s*(.*)$',arg,re.S)
    label=''; rest=arg
    if m: label=m.group(1); rest=m.group(2)
    before=src[max(0,i-60):i]
    fm=re.search(r'([\w.]+)\s*$',before)
    name=fm.group(1).split('.')[-1] if fm else ''
    return opener,name,label,rest

res=[]
for f in sorted(swift_files(ROOT)):
    src=open(f).read(); rel=f[len(ROOT)+1:]
    for lit in lex(src):
        enc=enclosing(src,lit['start'])
        kind='other'
        if enc:
            opener,name,label,rest=enc
            # rest must be only ternary/coalescing pieces
            simple = re.fullmatch(r'(?:[\w.!?\s()=<>&|]*\?\s*|.*\?\?\s*|.*:\s*)?',rest or '',re.S) is not None
            if opener=='(' and name=='String' and label=='localized': kind='loc'
            elif opener=='(' and name=='LocalizedStringResource' and label in ('',): kind='loc'
            elif opener=='(' and name in LOC_FUNCS and label in LOC_FUNCS[name]:
                if rest=='' or re.search(r'(\?|:|\?\?)\s*$',rest): kind='loc'
            elif name=='Text' and label=='verbatim': kind='verbatim'
        pre=src[max(0,lit['start']-40):lit['start']]
        if re.search(r'LocalizedStringResource\s*=\s*$',pre) or re.search(r'LocalizedStringKey\s*=\s*$',pre): kind='loc'
        res.append(dict(file=rel,line=lit['line'],segs=lit['segs'],kind=kind,ctx=re.sub(r'\s+',' ',src[max(0,lit['start']-100):lit['start']]),enc=enc[1:3] if enc else None))
json.dump(res,open('lits2.json','w'),ensure_ascii=False)
from collections import Counter
print(Counter(r['kind'] for r in res))
