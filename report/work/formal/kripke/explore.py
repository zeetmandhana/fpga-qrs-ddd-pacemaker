# size candidate Kripke abstractions (ticks always on; RTL semantics)
LRI,AVI,URI,PVARP,VRP,VA=10,2,5,4,3,3
AEI=LRI-AVI
def step(s, a, v, pvarp_on=True):
    ph,t_v,t_av,armed = s
    tv=min(t_v+1,LRI+1); tav=t_av+1 if ph==1 else 0
    VS = v and tv>=VRP
    VP = (not VS) and ph==1 and tav>=AVI and tv>=URI
    bl = pvarp_on and tv<PVARP
    AS = (not VS) and (not VP) and ph==0 and a and not bl
    AP = (not VS) and (not VP) and ph==0 and not AS and tv>=AEI
    nph = 0 if (VS or VP) else (1 if (AS or AP) else ph)
    ntv = 0 if (VS or VP) else tv
    ntav = 0 if (VS or VP or AS or AP) else tav
    narmed = True if (VS or VP) else (False if a else armed)
    ev = "VS" if VS else "VP" if VP else "AS" if AS else "AP" if AP else "-"
    up = (VS or VP) and tv<=URI
    return (nph,ntv,ntav,narmed), ev, up
def explore(env, pvarp_on):
    init=((0,LRI,0,False),"-",False)
    seen={init}; fr=[init]; E=[]
    while fr:
        s=fr.pop(); (reg,_,_)=s
        tv=min(reg[1]+1,LRI+1)
        if env=="retro_nd":   # AV block; retrograde P may or may not conduct
            choices=[(False,False)] + ([(True,False)] if reg[3] and tv==VA else [])
        elif env=="retro":
            choices=[(reg[3] and tv==VA, False)]
        for a,v in choices:
            n=step(reg,a,v,pvarp_on); E.append((s,n))
            if n not in seen: seen.add(n); fr.append(n)
    return seen,E
for env in ("retro","retro_nd"):
    for pv in (True,False):
        S,E=explore(env,pv); print(env,"pvarp" if pv else "BUG", len(S),"states",len(E),"edges")

if __name__=="__main__":
    import collections
    S,E=explore("retro_nd",False)
    # BFS numbering from init
    init=((0,LRI,0,False),"-",False)
    succ=collections.defaultdict(list)
    for s,n in E: succ[s].append(n)
    order=[init]; q=[init]
    while q:
        s=q.pop(0)
        for n in sorted(succ[s], key=lambda x:(x[1]!="-",x[0])):
            if n not in order: order.append(n); q.append(n)
    idx={s:i for i,s in enumerate(order)}
    for s in order:
        (ph,tv,tav,arm),ev,up=s
        print(f"s{idx[s]:<2} ph={'AVI' if ph else 'AEI'} t_v={tv:<2} t_av={tav} armed={int(arm)} ev={ev:2} upper={int(up)} -> {[ 's%d'%idx[n] for n in succ[s]]}")
