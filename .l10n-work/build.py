import json,sys
from validate import load, ks, check_pair
LANGS=['es','pt-BR','fr','de','it','ja','ko','zh-Hans','hi','id','ar','tr','th','vi']
NONTRANS={0,249,893,25,31,35,39,65,69,77,78,87,88,121,164,261,465,466,510,514,719,823,886,976,1001,1017,1122,1124,1133,1134,1136,1131}
# Keys whose English text differs from the key.
SPECIAL={'script.block.take':{'en':'Take'}}
EXTRA=json.load(open('extra.json')) if __import__('os').path.exists('extra.json') else {}
def gaps(lang):
    d=load(lang)
    return [i for i in range(len(ks)) if i not in NONTRANS and i not in d]
def build(out):
    strings={}
    data={l:load(l) for l in LANGS}
    for i,k in enumerate(ks):
        if i in NONTRANS:
            strings[k]={'shouldTranslate':False}; continue
        locs={}
        for l in LANGS:
            if i in data[l]:
                assert check_pair(k,data[l][i]) is None,(l,i)
                locs[l]={'stringUnit':{'state':'translated','value':data[l][i]}}
        strings[k]={'localizations':locs} if locs else {}
    for key,base in SPECIAL.items():
        locs={'en':{'stringUnit':{'state':'translated','value':base['en']}}}
        for l in LANGS:
            v=EXTRA.get(l,{}).get(key)
            if v: locs[l]={'stringUnit':{'state':'translated','value':v}}
        strings[key]={'comment':"Opinion script block: the creator's opinion, as in “hot take”.",'extractionState':'manual','localizations':locs}
    catalog={'sourceLanguage':'en','strings':dict(sorted(strings.items(),key=lambda kv: kv[0])),'version':'1.0'}
    s=json.dumps(catalog,ensure_ascii=False,indent=2,separators=(',',' : '))
    open(out,'w').write(s+'\n')
if __name__=='__main__':
    if sys.argv[1]=='gaps':
        for l in sys.argv[2:]:
            g=gaps(l); print(l,len(g),[ (i,ks[i]) for i in g][:60])
    else:
        build(sys.argv[2])
