"""Swift string literal lexer: yields (file, line, start, end, raw_body, segments) for each literal.
segments: list of ('text', str) / ('interp', expr_source)."""
import re, os, sys

def lex(src):
    i=0; n=len(src); line=1
    out=[]
    while i<n:
        c=src[i]
        if c=='\n': line+=1; i+=1; continue
        if src.startswith('//',i):
            j=src.find('\n',i); i=n if j<0 else j; continue
        if src.startswith('/*',i):
            j=src.find('*/',i+2); line+=src.count('\n',i,j); i=j+2; continue
        # raw strings #"..."#
        if c=='#' and i+1<n and src[i+1]=='"':
            j=i; hashes=0
            while src[j]=='#': hashes+=1; j+=1
            multi=src.startswith('"""',j)
            q='"""' if multi else '"'
            term=q+'#'*hashes
            k=src.find(term,j+len(q))
            body=src[j+len(q):k]
            out.append(dict(line=line,start=i,end=k+len(term),segs=[('text',body)],raw=True,multi=multi))
            line+=src.count('\n',i,k); i=k+len(term); continue
        if c=='"':
            multi=src.startswith('"""',i)
            j=i+(3 if multi else 1)
            segs=[]; buf=''
            startline=line
            while True:
                if multi and src.startswith('"""',j): j+=3; break
                if not multi and src[j]=='"': j+=1; break
                ch=src[j]
                if ch=='\\':
                    nx=src[j+1]
                    if nx=='(':
                        # interpolation
                        depth=1; k=j+2; inner_start=k
                        while depth:
                            ck=src[k]
                            if ck=='"':
                                # nested string: skip
                                sub=lex_one(src,k)
                                k=sub; continue
                            if ck=='(': depth+=1
                            elif ck==')': depth-=1
                            k+=1
                        if buf: segs.append(('text',buf)); buf=''
                        segs.append(('interp',src[inner_start:k-1]))
                        j=k; continue
                    esc={'n':'\n','t':'\t','"':'"','\\':'\\','0':'\0',"'":"'",'r':'\r'}
                    if nx in esc: buf+=esc[nx]; j+=2; continue
                    if nx=='u':
                        k=src.find('}',j); buf+=chr(int(src[j+3:k],16)); j=k+1; continue
                    if nx=='\n': j+=2; line+=1; continue
                    buf+=nx; j+=2; continue
                if ch=='\n': line+=1
                buf+=ch; j+=1
            if buf: segs.append(('text',buf))
            if multi:
                segs=dedent_multi(segs)
            out.append(dict(line=startline,start=i,end=j,segs=segs,raw=False,multi=multi))
            i=j; continue
        i+=1
    return out

def lex_one(src,i):
    # returns index after the string literal starting at i
    multi=src.startswith('"""',i)
    j=i+(3 if multi else 1)
    while True:
        if multi and src.startswith('"""',j): return j+3
        if not multi and src[j]=='"': return j+1
        if src[j]=='\\':
            if src[j+1]=='(':
                depth=1;k=j+2
                while depth:
                    if src[k]=='"': k=lex_one(src,k); continue
                    if src[k]=='(':depth+=1
                    elif src[k]==')':depth-=1
                    k+=1
                j=k; continue
            j+=2; continue
        j+=1

def dedent_multi(segs):
    # multi-line: strip first newline and common indentation (closing delimiter indentation)
    full=''.join(s if t=='text' else '\x00' for t,s in segs)
    # approximate
    text=''.join(s for t,s in segs if t=='text')
    lines=full.split('\n')
    if lines and lines[0].strip()=='' : lines=lines[1:]
    indent=len(lines[-1]) if lines and lines[-1].strip()=='' else 0
    if lines and lines[-1].strip()=='': lines=lines[:-1]
    res='\n'.join(l[indent:] for l in lines)
    # rebuild segs
    parts=res.split('\x00'); interps=[s for t,s in segs if t=='interp']
    new=[]
    for idx,p in enumerate(parts):
        if p: new.append(('text',p))
        if idx<len(interps): new.append(('interp',interps[idx]))
    return new

def swift_files(root):
    for d,_,fs in os.walk(root):
        for f in fs:
            if f.endswith('.swift'): yield os.path.join(d,f)
