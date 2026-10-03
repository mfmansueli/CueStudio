import json,re,sys,glob,os
ks=json.load(open('ordered.json'))
SPEC=re.compile(r'%(?:(\d+)\$)?(@|lld|lf|d|f|%)')
def specs(s):
    out=[]; pos=0
    for m in SPEC.finditer(s):
        if m.group(2)=='%': out.append(('%%',None)); continue
        out.append((m.group(2), int(m.group(1)) if m.group(1) else None))
    return out
def check_pair(src,tr):
    a=specs(src); b=specs(tr)
    if [x for x,_ in a if x=='%%'].__len__()!=[x for x,_ in b if x=='%%'].__len__(): return 'percent mismatch'
    a=[t for t,_ in a if t!='%%']; bb=[(t,p) for t,p in b if t!='%%']
    if len(a)!=len(bb): return f'count {len(a)} vs {len(bb)}'
    if any(p is not None for _,p in bb):
        if not all(p is not None for _,p in bb): return 'mixed positional'
        mapped=sorted(bb,key=lambda x:x[1])
        if [p for _,p in mapped]!=list(range(1,len(a)+1)): return 'bad positions'
        if [t for t,_ in mapped]!=a: return 'types (positional)'
    else:
        if [t for t,_ in bb]!=a: return 'types/order'
    return None
def load(lang):
    d={}
    for f in sorted(glob.glob(f'tr/{lang}.*')):
        for n,line in enumerate(open(f).read().split('\n'),1):
            if not line.strip(): continue
            idx,_,text=line.partition('|')
            idx=int(idx)
            text=text.replace('\\n','\n')
            if idx in d: print(f'{lang}: duplicate {idx}')
            d[idx]=text
    return d
if __name__=='__main__':
    langs=sys.argv[1:]
    for lang in langs:
        d=load(lang); errs=0
        for idx,text in d.items():
            if idx>=len(ks): print(lang,idx,'out of range'); errs+=1; continue
            e=check_pair(ks[idx],text)
            if e: print(f'{lang} {idx}: {e}\n   src={ks[idx]!r}\n   tr ={text!r}'); errs+=1
        print(lang,'entries',len(d),'errors',errs)
