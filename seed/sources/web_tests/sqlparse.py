import re, json
def tuples(sql, table):
    """All value tuples of INSERT INTO <table> (...) VALUES (...)[, (...)]. Returns list of (cols, values)."""
    out=[]
    for m in re.finditer(r'INSERT INTO\s+'+re.escape(table)+r'\s*\(([^)]*)\)\s*VALUES\s*', sql):
        cols=[c.strip() for c in m.group(1).split(',')]
        i=m.end()
        while True:
            while sql[i].isspace(): i+=1
            if sql[i]!='(': break
            vals,i=_tuple(sql,i)
            out.append(dict(zip(cols,vals)))
            while sql[i].isspace(): i+=1
            if sql[i]==',': i+=1; continue
            break
    return out
def _tuple(s,i):
    assert s[i]=='('; i+=1; vals=[]
    while True:
        while s[i].isspace(): i+=1
        if s[i]=="'":
            j=i+1; buf=[]
            while True:
                if s[j]=="'":
                    if j+1<len(s) and s[j+1]=="'": buf.append("'"); j+=2; continue
                    break
                buf.append(s[j]); j+=1
            v=''.join(buf); i=j+1
            if s.startswith('::jsonb',i): v=json.loads(v); i+=7
        else:
            j=i; depth=0
            while not (depth==0 and s[j] in ',)'):
                if s[j]=='(': depth+=1
                if s[j]==')': depth-=1
                j+=1
            raw=s[i:j].strip(); i=j
            v=None if raw.upper()=='NULL' else (True if raw.upper()=='TRUE' else False if raw.upper()=='FALSE' else (int(raw) if re.fullmatch(r'-?\d+',raw) else raw))
        vals.append(v)
        while s[i].isspace(): i+=1
        if s[i]==',': i+=1; continue
        if s[i]==')': return vals,i+1
