import sys,re
def peek(path, names):
    ids={}; scope=[]; vals={}; t=None; rows=[]
    for line in open(path):
        w=line.split()
        if not w: continue
        if w[0]=="$scope": scope.append(w[2])
        elif w[0]=="$upscope": scope.pop()
        elif w[0]=="$var":
            full=".".join(scope[1:]+[w[4]])
            ids.setdefault(w[3],[]).append(full)
        elif w[0].startswith("#"):
            if t is not None: rows.append((t,dict(vals)))
            t=int(w[0][1:])
        elif w[0][0] in "01xz" and len(w)==1:
            for n in ids.get(w[0][1:],[]): vals[n]=w[0][0]
        elif w[0][0]=="b":
            for n in ids.get(w[1],[]): vals[n]=w[0][1:]
    rows.append((t,dict(vals)))
    def v(d,n):
        x=d.get(n,"?")
        try: return str(int(x,2))
        except: return x
    print("time "+" ".join(names))
    for t,d in rows:
        print(f"{t:5d} "+" ".join(f"{v(d,n):>6}" for n in names))
peek(sys.argv[1], sys.argv[2].split(","))
