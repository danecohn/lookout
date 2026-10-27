#!/usr/bin/env python3
"""Contrast audit for the VigilTech colours in Sources/Lookout/Theme.swift (no GUI needed).
Translucent layers are composited over the worst-case backdrops (white and black desktop behind the sidebar material,
and every wallpaper stop behind start-page panels). Exit status 1 if any pair is below its threshold."""
import sys
def rgb(h): return ((h>>16)&255,(h>>8)&255,h&255)
def over(top,a,bot): return tuple(round(t*a+b*(1-a)) for t,b in zip(top,bot))
def lum(c):
    f=lambda v:(v/255/12.92) if v/255<=0.03928 else ((v/255+0.055)/1.055)**2.4
    r,g,b=map(f,c); return 0.2126*r+0.7152*g+0.0722*b
def ratio(a,b):
    la,lb=sorted((lum(a),lum(b)),reverse=True); return (la+0.05)/(lb+0.05)
T={ 'light':dict(bg=0xf6f1f4,surface=0xfffbfd,glass=(0xfffafc,.96),label=0x17101a,label2=0x6b5d68,accent=0xa8003a,button=0xd6004a,
        soft=(0xff0058,.11),fill=(0x6e4664,.10),wall=[0xfff4f8,0xffc0d4,0xff5c8f],arcA=(0xffffff,.40),arcB=(0xa8003a,.22)),
    'dark':dict(bg=0x120a14,surface=0x1e1422,glass=(0x221226,.96),label=0xf7eef2,label2=0xb7a5b1,accent=0xff7aa6,button=0xd6004a,
        soft=(0xff4d86,.18),fill=(0xffbedc,.09),wall=[0x140812,0x2b0a1e,0x5a0a2c],arcA=(0xff8fb3,.13),arcB=(0x1f0009,.50)) }
bad=0
for theme,t in T.items():
    print(f'== {theme}')
    # surfaces the text can sit on
    surfaces={'bg':[rgb(t['bg'])],'surface':[rgb(t['surface'])]}
    glass=[over(rgb(t['glass'][0]),t['glass'][1],bd) for bd in [(255,255,255),(0,0,0)]]
    surfaces['sidebar glass (over white/black desktop)']=glass
    surfaces['selected tab row on glass']=[over(rgb(t['soft'][0]),t['soft'][1],g) for g in glass]
    surfaces['fill chip on glass']=[over(rgb(t['fill'][0]),t['fill'][1],g) for g in glass]
    surfaces['fill on surface']=[over(rgb(t['fill'][0]),t['fill'][1],rgb(t['surface']))]
    walls=[]
    for w in t['wall']:
        walls+= [w and rgb(w), over(rgb(t['arcA'][0]),t['arcA'][1],rgb(w)), over(rgb(t['arcB'][0]),t['arcB'][1],rgb(w))]
    surfaces['start-page scrim (94% surface over wallpaper)']=[over(rgb(t['surface']),.94,w) for w in walls]
    for sname,bgs in surfaces.items():
        for fname,thr in (('label',4.5),('label2',4.5),('accent',4.5)):
            worst=min(ratio(rgb(t[fname]),b) for b in bgs)
            flag='OK ' if worst>=thr else 'LOW'; bad+= worst<thr
            print(f'  {flag} {fname:7} on {sname:50} {worst:5.2f}')
    for nm,fg,bg in (('white on button',(255,255,255),rgb(t['button'])),('white on pressed button (#a8003a)',(255,255,255),rgb(0xa8003a)),
                     ('label2 on disabled button fill (over surface)',rgb(t['label2']),over(rgb(t['fill'][0]),t['fill'][1],rgb(t['surface'])))):
        r=ratio(fg,bg); flag='OK ' if r>=4.5 else 'LOW'; bad+= r<4.5; print(f'  {flag} {nm:62} {r:5.2f}')
print('FAILURES:',bad); sys.exit(1 if bad else 0)
