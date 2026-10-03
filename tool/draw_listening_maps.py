"""Draw the 8 listening map / plan images (P1-PM … P4-PM, 2 each) as exam-style line drawings.

Letters are placed exactly where the listening scripts describe them.
Output: assets/listening/maps/<CODE>_map<n>.png (SVG drawn here, rendered with Playwright Chromium).
usage: python3 tool/draw_listening_maps.py   then re-run tool/import_listening_bank.py <pdf>
"""
import glob, os, math, re, tempfile
OUT=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),'assets','listening','maps')
os.makedirs(OUT, exist_ok=True)
TMP=tempfile.mkdtemp()
F="font-family='DejaVu Sans, Arial, sans-serif'"
class Svg:
    def __init__(s,w,h,title,north=True):
        s.w,s.h=w,h; s.fills=[]; s.p=[
          f"<text x='{w/2}' y='70' text-anchor='middle' {F} font-size='40' font-weight='bold'>{title}</text>"]
        if north: s.north(w-90,120)
    def add(s,x): s.p.append(x)
    # colour fills are painted first (under every line), in call order
    def fill(s,x1,y1,x2,y2,c,rx=0):
        s.fills.append(f"<rect x='{x1}' y='{y1}' width='{x2-x1}' height='{y2-y1}' rx='{rx}' fill='{c}'/>")
    def fillpath(s,d,c):
        s.fills.append(f"<path d='{d}' fill='{c}'/>")
    def fillcircle(s,x,y,r,c):
        s.fills.append(f"<circle cx='{x}' cy='{y}' r='{r}' fill='{c}'/>")
    def window(s,x1,y1,x2,y2,sw=7):
        s.add(f"<line x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}' stroke='#9FD0EA' stroke-width='{sw}'/>")
        s.add(f"<line x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}' stroke='#EAF6FC' stroke-width='{max(1,sw-6)}'/>")
    def rect(s,x1,y1,x2,y2,sw=5,fill='none',dash=None):
        d=f" stroke-dasharray='{dash}'" if dash else ''
        s.add(f"<rect x='{x1}' y='{y1}' width='{x2-x1}' height='{y2-y1}' fill='{fill}' stroke='#3A3A3A' stroke-width='{sw}'{d}/>")
    def line(s,x1,y1,x2,y2,sw=5,color='#3A3A3A',dash=None,cap='butt'):
        d=f" stroke-dasharray='{dash}'" if dash else ''
        s.add(f"<line x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}' stroke='{color}' stroke-width='{sw}' stroke-linecap='{cap}'{d}/>")
    def path(s,d,sw=4,fill='none',color='#3A3A3A',dash=None):
        dd=f" stroke-dasharray='{dash}'" if dash else ''
        s.add(f"<path d='{d}' fill='{fill}' stroke='{color}' stroke-width='{sw}' stroke-linejoin='round' stroke-linecap='round'{dd}/>")
    def gap(s,x1,y1,x2,y2,sw=8,c='white',door=True,side=1):  # erase wall for a door (+ swing arc)
        s.add(f"<line x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}' stroke='{c}' stroke-width='{sw}'/>")
        if not door or sw>=14: return  # outer entrances: open gap + arrow, no swing arc
        if x1==x2:
            r=abs(y2-y1); hx,hy=x1,min(y1,y2); ex=hx+side*r
            s.add(f"<path d='M{hx},{hy} L{ex},{hy} A{r},{r} 0 0 {1 if side>0 else 0} {hx},{hy+r}' fill='none' stroke='#6A6A6A' stroke-width='2'/>")
        elif y1==y2:
            r=abs(x2-x1); hx,hy=min(x1,x2),y1; ey=hy-side*r
            s.add(f"<path d='M{hx},{hy} L{hx},{ey} A{r},{r} 0 0 {1 if side>0 else 0} {hx+r},{hy}' fill='none' stroke='#6A6A6A' stroke-width='2'/>")
    def text(s,x,y,t,size=26,anchor='middle',weight='normal',rot=None,style='normal'):
        r=f" transform='rotate({rot} {x} {y})'" if rot is not None else ''
        s.add(f"<text x='{x}' y='{y}' text-anchor='{anchor}' dominant-baseline='middle' {F} font-size='{size}' font-weight='{weight}' font-style='{style}'{r}>{t}</text>")
    def letter(s,x,y,L,size=50):
        s.add(f"<text x='{x}' y='{y+3}' text-anchor='middle' dominant-baseline='middle' {F} font-size='{size}' font-weight='bold' fill='#151515' stroke='white' stroke-width='7' stroke-linejoin='round' paint-order='stroke'>{L}</text>")
    def arrow(s,x1,y1,x2,y2,sw=4):
        a=math.atan2(y2-y1,x2-x1); l=18
        p1=(x2-l*math.cos(a-0.45),y2-l*math.sin(a-0.45)); p2=(x2-l*math.cos(a+0.45),y2-l*math.sin(a+0.45))
        s.line(x1,y1,x2,y2,sw)
        s.add(f"<polygon points='{x2},{y2} {p1[0]},{p1[1]} {p2[0]},{p2[1]}' fill='#111'/>")
    def north(s,x,y):
        s.add(f"<polygon points='{x},{y-45} {x-16},{y+10} {x},{y} {x+16},{y+10}' fill='#111'/>")
        s.text(x,y+35,'N',28,weight='bold')
    def save(s,name):
        svg=(f"<svg xmlns='http://www.w3.org/2000/svg' width='{s.w}' height='{s.h}' viewBox='0 0 {s.w} {s.h}'>"
             f"<rect width='{s.w}' height='{s.h}' fill='white'/>"+''.join(s.fills)+''.join(s.p)+"</svg>")
        open(os.path.join(TMP,name+'.svg'),'w').write(svg)

PEACH,SAND,ROSE,TAUPE,LILAC,SLATE,SKY,SAGE,BLUE,MAUVE,CORR,YELLOW='#F6D6BD','#EBD9A6','#E3AE9A','#DCD4CC','#DDD3E8','#C8D3E6','#D3EAF2','#D2E6CB','#A9D3E6','#DDCFD1','#EEEEEE','#F4E5B8'
def ell(cx,cy,rx,ry): return f"M{cx-rx},{cy} a{rx},{ry} 0 1,0 {2*rx},0 a{rx},{ry} 0 1,0 {-2*rx},0 Z"

# ── P1-PM ground floor ─────────────────────────────────────────────
s=Svg(1200,1650,'Riverside Mall · Ground floor')
X1,X2,Y1,Y2=100,1100,170,1480; CL,CR=440,760
s.rect(X1,Y1,X2,Y2,7)
# north strip
s.line(X1,440,CL,440); s.line(CR,440,X2,440); s.line(CL,Y1,CL,440); s.line(CR,Y1,CR,440)
# west and east unit walls
for x in (CL,CR): s.line(x,440,x,Y2)
for y in (760,1010,1250):
    s.line(X1,y,CL,y); s.line(CR,y,X2,y)
# shop doors onto corridor
for y1,y2 in ((560,640),(850,920),(1100,1170),(1330,1400)):
    s.gap(CL,y1,CL,y2); s.gap(CR,y1,CR,y2)
s.gap(CL,300,CL,370); s.gap(CR,300,CR,370)
# entrance
s.gap(540,Y2,660,Y2,14); s.arrow(600,1580,600,1500); s.text(600,1610,'Main entrance',28,weight='bold')
# fountain, desk, escalators
s.add("<circle cx='600' cy='760' r='62' fill='none' stroke='#111' stroke-width='4'/><circle cx='600' cy='760' r='30' fill='none' stroke='#111' stroke-width='2'/>")
s.text(600,850,'Fountain',22)
s.rect(470,700,515,820,3); [s.line(470,y,515,y,2) for y in range(712,820,14)]
s.text(492,690,'Escalators',18,rot=-90,anchor='start') if False else s.text(455,760,'Escalators',18,rot=-90)
s.rect(680,735,735,785,3)
s.text(600,1180,'Main corridor',24,rot=-90,style='italic')
s.letter(270,1365,'A'); s.letter(930,1365,'B'); s.letter(270,1130,'C'); s.letter(930,1130,'D')
s.letter(708,705,'E'); s.letter(270,300,'F'); s.letter(600,300,'G'); s.letter(930,300,'H')
s.letter(270,600,'I'); s.letter(930,600,'J')
s.fill(CL,Y1,CR,Y2,CORR); s.fill(CL,Y1,CR,440,SAND)
for (x1,x2),cols in (((X1,CL),(PEACH,SKY,TAUPE,SAGE,ROSE)),((CR,X2),(LILAC,SLATE,MAUVE,PEACH,LILAC))):
    for (y1,y2),c in zip(((Y1,440),(440,760),(760,1010),(1010,1250),(1250,Y2)),cols): s.fill(x1,y1,x2,y2,c)
s.fillcircle(600,760,62,BLUE); s.fill(470,700,515,820,'#D0D0D0'); s.fill(680,735,735,785,'#C9B08A')
s.rect(X1,Y1,X2,Y2,12)
for a,b in ((220,400),(500,700),(1060,1200),(1290,1440)): s.window(X1,a,X1,b,12); s.window(X2,a,X2,b,12)
for a,b in ((150,400),(800,1050)): s.window(a,Y1,b,Y1,12); s.window(a,Y2,b,Y2,12)
s.gap(540,Y2,660,Y2,16)
s.save('P1-PM_map1')

# ── P1-PM first floor ──────────────────────────────────────────────
s=Svg(1200,1650,'Riverside Mall · First floor')
s.rect(X1,Y1,X2,Y2,7)
s.line(CL,Y1,CL,Y2); s.line(CR,Y1,CR,Y2)
s.line(X1,830,CL,830); s.line(CR,830,X2,830)
for y1,y2 in ((480,560),(1120,1200)): s.gap(CL,y1,CL,y2); s.gap(CR,y1,CR,y2)
# far north room I
s.line(CL,420,CR,420); s.gap(560,420,640,420)
# balcony + atrium
s.line(CL,500,CR,500,2)
s.rect(480,520,720,780,3,dash='14 10'); s.text(600,650,'Atrium',24,style='italic')
s.text(600,860,'',1)
# escalators arriving (arrow north)
s.rect(565,900,635,1090,3); [s.line(565,y,635,y,2) for y in range(915,1090,15)]
s.arrow(600,1080,600,905,5); s.text(600,1120,'Escalators',20)
# south end split
s.line(CL,1300,CR,1300,3,dash='10 8'); s.line(600,1300,600,Y2,3)
s.letter(270,500,'F'); s.letter(270,1160,'A'); s.letter(930,500,'C'); s.letter(930,1160,'J')
s.letter(600,460,'B'); s.letter(600,290,'I'); s.letter(510,930,'D'); s.letter(690,930,'H')
s.letter(520,1390,'E'); s.letter(680,1390,'G')
s.fill(CL,Y1,CR,Y2,CORR); s.fill(CL,Y1,CR,420,SAND); s.fill(CL,420,CR,500,YELLOW); s.fill(480,520,720,780,SKY)
s.fill(X1,Y1,CL,830,PEACH); s.fill(X1,830,CL,Y2,SAGE); s.fill(CR,Y1,X2,830,LILAC); s.fill(CR,830,X2,Y2,ROSE)
s.fill(CL,1300,600,Y2,TAUPE); s.fill(600,1300,CR,Y2,SLATE); s.fill(565,900,635,1090,'#D0D0D0')
s.rect(X1,Y1,X2,Y2,12)
for a,b in ((220,400),(500,700),(1060,1200),(1290,1440)): s.window(X1,a,X1,b,12); s.window(X2,a,X2,b,12)
for a,b in ((150,400),(800,1050)): s.window(a,Y1,b,Y1,12); s.window(a,Y2,b,Y2,12)
s.save('P1-PM_map2')

# ── P2-PM reserve ──────────────────────────────────────────────────
# ring path round the lake; entrance south; right (east) = picnic area then overflow car park;
# left (west) = playground, boathouse on the west shore; bird hide at the top of the ring;
# waterfall inside the path on the NW shore; campsite in the NW woods; old mill NE by the stream;
# lookout tower halfway up the east side; viewing platform on the island.
s=Svg(1600,1260,'Maple Ridge Nature Reserve')
s.rect(80,120,1470,1060,4,dash='18 10')
s.line(0,1100,1600,1100,4); s.line(0,1150,1600,1150,4); s.text(160,1178,'Road',24,style='italic')
RCX,RCY,RX,RY=800,595,450,350
def rp(deg,dr=0): return (RCX+(RX+dr)*math.cos(math.radians(deg)), RCY+(RY+dr)*math.sin(math.radians(deg)))
# forest NW (campsite)
for tx,ty in [(130,170),(200,150),(270,180),(150,250),(120,330),(200,340),(290,320),(360,170),(350,300)]:
    s.path(f"M{tx},{ty-26} L{tx-18},{ty+10} L{tx+18},{ty+10} Z",3); s.line(tx,ty+10,tx,ty+20,3)
s.path("M205,250 L235,205 L265,250 Z",3,fill='#F4E5B8'); s.line(235,205,235,250,2)
s.text(240,375,'Woods',22,style='italic')
# hill on the east side (lookout)
for rx,ry in [(100,70),(68,46),(36,24)]:
    s.add(f"<ellipse cx='1365' cy='595' rx='{rx}' ry='{ry}' fill='none' stroke='#111' stroke-width='2'/>")
# lake + island
LK=ell(800,595,310,240)
s.path(LK,5)
s.add("<ellipse cx='820' cy='620' rx='70' ry='38' fill='none' stroke='#111' stroke-width='4'/>")
s.text(690,745,'Lake',30,style='italic'); s.text(820,670,'island',18,style='italic')
# stream from the north-east into the lake (path bridges it)
STR="M1300,120 C1270,175 1190,180 1150,240 C1110,300 1060,330 1010,385"
s.path(STR,4); s.text(1180,150,'Stream',22,style='italic',anchor='end')
# paths
g='#CDB38A'
s.path("M800,1060 L800,945",14,color=g)
s.path(ell(RCX,RCY,RX,RY),14,color=g)
s.line(1130,822,1210,895,14,color=g)
# waterfall: rocks + falling water on the NW shore, inside the path
for cx,cy in [(520,372),(548,358),(506,398)]:
    s.add(f"<ellipse cx='{cx}' cy='{cy}' rx='16' ry='11' fill='#BDBDBD' stroke='#3A3A3A' stroke-width='2'/>")
for i in range(3): s.path(f"M{532+i*10},{378+i*4} q6,14 0,26 q-6,12 2,22",2,color='#3C8DBA')
# boathouse + jetty on the west shore
s.rect(410,568,478,622,3); s.line(478,595,545,595,8,color='#8B6B4A')
# bird hide at the top of the ring
s.rect(765,168,835,222,3)
# old mill by the stream (building + wheel)
s.rect(1250,190,1350,262,3); s.add("<circle cx='1232' cy='240' r='22' fill='none' stroke='#3A3A3A' stroke-width='3'/>")
# picnic tables south-east of the gate
for tx,ty in [(905,990),(1080,985)]:
    s.rect(tx-28,ty-12,tx+28,ty+12,2); s.line(tx-28,ty-22,tx+28,ty-22,3); s.line(tx-28,ty+22,tx+28,ty+22,3)
# playground (swings) south-west of the gate
s.path("M380,990 L400,930 L420,990 M500,990 L480,930 L500,990 M400,930 L480,930",3)
s.line(430,930,430,965,2); s.line(455,930,455,965,2); s.line(422,966,438,966,3); s.line(447,966,463,966,3)
# entrance + car parks
s.gap(760,1060,840,1060,8,c='#E6F1DC',door=False); s.text(800,1082,'Entrance',22,weight='bold')
s.rect(560,975,730,1045,3); s.text(645,1010,'Main car park',19)
s.rect(1180,895,1440,1035,3)
for x in range(1220,1440,40): s.line(x,895,x,935,2)
s.letter(330,240,'A'); s.letter(444,598,'B'); s.letter(1310,975,'C'); s.letter(992,1010,'D'); s.letter(820,620,'E')
s.letter(1300,228,'F'); s.letter(330,975,'G'); s.letter(800,198,'H'); s.letter(1365,598,'I'); s.letter(495,450,'J')
s.fill(80,120,1470,1060,'#E6F1DC'); s.fill(90,130,400,390,'#C4E0B5',rx=60)
s.fillpath(ell(1365,595,100,70),'#D7E8C3'); s.fillpath(ell(1365,595,68,46),'#C9DFB1'); s.fillpath(ell(1365,595,36,24),'#BAD6A0')
s.fillpath(LK,BLUE)
s.fillpath(ell(820,620,70,38),'#E9D8A6'); s.fill(0,1100,1600,1150,'#CFCFCF'); s.fill(560,975,730,1045,'#DDDDDD'); s.fill(1180,895,1440,1035,'#DDDDDD')
s.fill(410,568,478,622,'#C9B08A'); s.fill(765,168,835,222,'#C9B08A'); s.fill(1250,190,1350,262,MAUVE)
s.line(0,1125,1600,1125,3,color='white',dash='30 24')
s.save('P2-PM_map1')

# ── P2-PM visitor centre ───────────────────────────────────────────
# entrance hall (south) → exhibition hall in the middle; back wall (north): permanent exhibition (back-left
# corner), lecture room, temporary exhibition, shop (back-right corner); two small rooms behind the hall
# (staff office left, resource room right); left wall: activity room, toilets (front corner);
# right wall: café (middle), first-aid room (front).
s=Svg(1200,1600,'Lake View Visitor Centre')
for x in range(160,1060,60): s.path(f"M{x},150 q15,-12 30,0 q15,12 30,0",2)
s.text(600,195,'Lake',26,style='italic')
BX1,BY1,BX2,BY2=150,250,1050,1450
WL,WR,BK,SM,EH=400,800,480,610,1250
s.rect(BX1,BY1,BX2,BY2,7)
s.line(WL,BY1,WL,BY2); s.line(WR,BY1,WR,BY2)
s.line(BX1,BK,WL,BK); s.line(WR,BK,BX2,BK); s.line(BX1,960,WL,960); s.line(WR,960,BX2,960)
s.line(460,BK,740,BK); s.line(460,BY1,460,SM); s.line(740,BY1,740,SM); s.line(600,BY1,600,SM); s.line(460,SM,740,SM)
s.line(WL,EH,WR,EH)
# doors
s.gap(560,BY2,640,BY2,14); s.arrow(600,1540,600,1460); s.text(600,1570,'Entrance',28,weight='bold')
s.gap(WL,400,WL,450); s.gap(WR,400,WR,450,side=-1)          # corner rooms → hall
s.gap(460,300,460,350,side=-1); s.gap(740,300,740,350)      # lecture / temporary → side corridors
s.gap(510,SM,550,SM); s.gap(650,SM,690,SM)                  # small rooms → hall
s.gap(WL,690,WL,750); s.gap(WR,690,WR,750,side=-1)          # activity room / café
s.gap(WL,1320,WL,1380); s.gap(WR,1320,WR,1380,side=-1)      # toilets / first aid from entrance hall
s.gap(530,EH,670,EH,10,door=False)
s.rect(540,1360,660,1400,3)
s.text(600,930,'Exhibition hall',26,style='italic'); s.text(600,1300,'Entrance hall',22,style='italic')
s.letter(275,365,'G'); s.letter(530,365,'J'); s.letter(670,365,'B'); s.letter(925,365,'C')
s.letter(530,535,'I'); s.letter(670,535,'F')
s.letter(275,720,'E'); s.letter(275,1205,'H'); s.letter(925,720,'A'); s.letter(925,1205,'D')
s.fill(150,110,1050,215,'#DCEFF6')
s.fill(BX1,BY1,WL,BK,PEACH); s.fill(WL,BY1,WR,BK,SKY); s.fill(460,BY1,600,BK,YELLOW); s.fill(600,BY1,740,BK,LILAC); s.fill(WR,BY1,BX2,BK,SAND)
s.fill(BX1,BK,WL,960,SAGE); s.fill(BX1,960,WL,BY2,ROSE); s.fill(WR,BK,BX2,960,MAUVE); s.fill(WR,960,BX2,BY2,SLATE)
s.fill(WL,BK,WR,EH,SKY); s.fill(460,BK,600,SM,TAUPE); s.fill(600,BK,740,SM,TAUPE); s.fill(WL,EH,WR,BY2,CORR)
s.fill(540,1360,660,1400,'#C9B08A'); s.rect(BX1,BY1,BX2,BY2,12)
s.window(170,BY1,380,BY1,12); s.window(475,BY1,585,BY1,12); s.window(615,BY1,725,BY1,12); s.window(820,BY1,1030,BY1,12)
s.window(BX1,560,BX1,880,12); s.window(BX2,560,BX2,880,12); s.window(BX1,1060,BX1,1380,12); s.window(BX2,1060,BX2,1380,12)
s.gap(560,BY2,640,BY2,16)
s.save('P2-PM_map2')

# ── P3-PM lab ──────────────────────────────────────────────────────
# door mid south wall; safety cupboard on the south wall just right of the door; sink in the SW corner;
# instructor's desk in the centre facing the door, tensile tester just right of it; workbenches 1-3 along
# the north wall (left → right); storage cupboard down the east wall; fume cupboard at the north end of the
# east wall just below workbench 3; emergency shower in the SE corner at the bottom of the storage cupboard.
s=Svg(1600,1200,'Materials-testing lab')
s.rect(150,200,1450,1050,7)
s.gap(760,1050,840,1050,14); s.arrow(800,1140,800,1060); s.text(800,1170,'Door',26,weight='bold')
s.gap(1450,440,1450,520,14); s.arrow(1460,480,1560,480); s.text(1530,640,'To equipment store',20,rot=-90)
LAB=[((250,200,560,270),SAND),((650,200,950,270),SAND),((1040,200,1340,270),SAND),   # workbenches
     ((1370,290,1450,420),LILAC),((1390,560,1450,930),SLATE),((1340,950,1450,1050),SKY), # fume, storage, shower
     ((870,990,1010,1050),ROSE),((150,940,270,1050),SAGE),                                 # safety cupboard, sink
     ((690,560,910,660),TAUPE),((950,575,1030,645),PEACH)]                                  # desk, tensile tester
for r,c in LAB: s.rect(*r,sw=3)
s.add("<ellipse cx='205' cy='1000' rx='34' ry='24' fill='white' stroke='#3A3A3A' stroke-width='2'/>")
s.add("<circle cx='1395' cy='1000' r='30' fill='none' stroke='#3A3A3A' stroke-width='2'/>"); s.line(1374,979,1416,1021,2); s.line(1416,979,1374,1021,2)
s.add("<circle cx='800' cy='700' r='22' fill='#EDEDED' stroke='#3A3A3A' stroke-width='3'/>")
s.letter(405,320,'A'); s.letter(800,320,'J'); s.letter(1190,320,'D'); s.letter(1315,365,'I'); s.letter(1330,745,'B')
s.letter(1280,1000,'G'); s.letter(940,945,'F'); s.letter(320,1000,'C'); s.letter(780,610,'H'); s.letter(990,612,'E',44)
s.fill(150,200,1450,1050,'#F3F0EA')
for r,c in LAB: s.fill(*r,c)
s.rect(150,200,1450,1050,12)
for a,b in ((270,540),(670,930),(1060,1320)): s.window(a,200,b,200,12)
s.window(150,420,150,820,12); s.gap(760,1050,840,1050,16); s.gap(1450,440,1450,520,16,side=-1)
s.save('P3-PM_map1')

# ── P3-PM store ────────────────────────────────────────────────────
# door mid west wall; calibration bench in the centre; three shelf units on the north wall (microscopes
# nearest the door, hand tools middle, spare parts far/east end); logbook station on the east wall,
# northern half, charging station below it; glove drawer at the west end of the south wall, waste bin at
# its east end; first-aid kit just inside the door on the left (north), fire extinguisher on the right.
s=Svg(1600,1200,'Equipment store')
s.rect(200,200,1400,1000,7)
s.gap(200,560,200,640,14); s.arrow(60,600,190,600); s.text(30,660,'Door from lab',20,anchor='start')
s.text(800,1050,'Window',20,style='italic')
ST=[((650,520,950,680),SKY),((260,200,560,260),SAND),((650,200,950,260),SAND),((1040,200,1340,260),SAND),
    ((1340,300,1400,480),LILAC),((1340,680,1400,860),SLATE),((240,940,440,1000),ROSE),((1300,900,1400,1000),SAGE),
    ((200,450,250,530),PEACH),((200,670,250,730),'#F2B8A8')]
for r,c in ST: s.rect(*r,sw=3)
s.add("<circle cx='1350' cy='950' r='32' fill='none' stroke='#3A3A3A' stroke-width='2'/>")
s.letter(800,600,'D'); s.letter(410,310,'H'); s.letter(800,310,'A'); s.letter(1190,310,'J'); s.letter(1290,390,'F')
s.letter(1290,770,'C'); s.letter(340,890,'I'); s.letter(1240,945,'B'); s.letter(300,490,'E'); s.letter(300,700,'G')
s.fill(200,200,1400,1000,'#F3F0EA')
for r,c in ST: s.fill(*r,c)
s.rect(200,200,1400,1000,12); s.gap(200,560,200,640,16,side=1)
s.window(680,1000,920,1000,12)
s.save('P3-PM_map2')

# ── P4-PM bathhouse ────────────────────────────────────────────────
# the lecturer reads the labels A-J in order: A changing room (inside the west entrance), B cold room
# (east of A), C warm room, D hot room (east end), E furnace (under the hot room, dashed = below floor),
# F exercise yard (north of A), G garden (south of A), H cold plunge pool (by the cold room),
# I massage room (next to the plunge pool), J latrine (by the entrance).
s=Svg(1600,950,'Roman bathhouse · floor plan')
s.rect(200,150,1300,820,9)
s.line(450,150,450,570,6); s.line(700,150,700,820,6); s.line(950,150,950,820,6)
s.line(200,320,700,320,6); s.line(200,570,700,570,6); s.line(700,320,950,320,6)
s.line(200,480,300,480,5); s.line(300,480,300,570,5)
s.rect(500,190,650,280,3)
for px,py in [(240,610),(300,640),(250,700),(330,690),(270,760),(390,620),(520,640),(600,700),(640,620),(560,760),(410,760),(660,770)]:
    s.add(f"<circle cx='{px}' cy='{py}' r='16' fill='#B9D9A8' stroke='#3A3A3A' stroke-width='2'/>")
s.path("M230,180 L420,180 L420,290 L230,290 Z",2,dash='4 10')
s.gap(200,360,200,430,20); s.arrow(50,395,190,395); s.text(30,455,'Entrance',24,anchor='start',weight='bold')
s.gap(450,410,450,480,10); s.gap(700,410,700,480,10); s.gap(950,410,950,480,10)
s.gap(560,320,620,320,10,side=-1); s.gap(700,200,700,260,10); s.gap(300,320,360,320,10,side=-1); s.gap(360,570,420,570,10)
s.gap(300,500,300,550,8)
s.path("M1020,640 L1230,640 L1230,900 L1020,900 Z",4,dash='16 10'); s.text(1340,905,'- - - below floor level',18,style='italic')
s.letter(380,440,'A'); s.letter(575,450,'B'); s.letter(825,580,'C'); s.letter(1125,400,'D'); s.letter(1125,860,'E')
s.letter(325,235,'F'); s.letter(450,690,'G'); s.letter(575,235,'H'); s.letter(825,235,'I'); s.letter(250,525,'J',44)
s.fill(200,150,1300,820,'#EFE7DA')
for r,c in (((200,150,450,320),'#EADFC2'),((200,320,450,570),PEACH),((200,570,700,820),SAGE),((200,480,300,570),MAUVE),((450,150,700,320),LILAC),
            ((450,320,700,570),SKY),((700,320,950,820),YELLOW),((700,150,950,320),ROSE),((950,150,1300,820),TAUPE)):
    s.fill(*r,c)
s.fill(500,190,650,280,BLUE); s.fill(1020,640,1230,900,'#F6C9A8')
s.save('P4-PM_map1')

# ── P4-PM hypocaust ────────────────────────────────────────────────
# labels read in order: A furnace mouth, B brick pillars, C raised floor, D hollow wall tiles, E chimney,
# F ash pit (below the furnace), G fuel store, H service passage, I temperature vent, J inspection hatch.
# The furnace sits under the west end of the hot room, so the hot room is directly above it.
s=Svg(1600,950,'Hypocaust · cross-section',north=False)
GY=720
for x in range(0,1600,30): s.line(x,GY+10,x+30,GY+60,1.5)
s.line(0,GY,1600,GY,5)
# service passage + ash pit (cut out of earth)
s.rect(30,GY+40,450,GY+120,4,fill='#F3ECE0'); s.rect(460,GY,620,GY+100,4,fill='#E8E1D6')
s.line(450,GY+40,460,GY+40,4)
# fuel store (logs)
for lx,ly in [(70,690),(130,690),(190,690),(100,650),(160,650),(130,610)]:
    s.add(f"<circle cx='{lx}' cy='{ly}' r='26' fill='#C8A07A' stroke='#3A3A3A' stroke-width='3'/><circle cx='{lx}' cy='{ly}' r='8' fill='none' stroke='#111' stroke-width='2'/>")
# hot room walls, roof, floor, pillars
s.rect(400,280,440,GY,4); s.rect(1170,280,1250,GY,4)
for yy in range(300,700,50): s.rect(1182,yy,1238,yy+40,2)
s.line(350,280,1300,280,6)
s.rect(440,560,1170,605,4,fill='#D9CBB6')
# furnace under the west end of the floor
s.rect(440,605,640,GY,4,fill='#F6D6BD')
s.path("M480,715 q10,-50 25,-20 q10,-50 25,0 q15,-45 25,5 q10,-35 25,0",5,fill="#F4A259",color="#D9642A")
s.text(540,628,'Furnace',18,style='italic')
s.gap(400,640,440,640,4,door=False); s.gap(420,645,420,GY-4,44,door=False); s.line(400,640,440,640,4)
s.gap(480,GY,600,GY,8,door=False)
for px in range(670,1160,70): s.rect(px,605,px+35,GY,3,fill='#CFA98A')
s.gap(1085,560,1135,560,8,door=False); s.gap(1085,583,1135,583,40,door=False); s.line(1085,560,1085,605,3); s.line(1135,560,1135,605,3)
s.gap(400,537,440,537,24,door=False); s.line(400,525,440,525,3); s.line(400,550,440,550,3)
# chimney
s.rect(1175,130,1245,280,4); s.path("M1210,120 q-20,-20 0,-40 q20,-20 0,-40",3)
# hot air arrows
for x1 in (650,820,960): s.arrow(x1,690,x1+110,690,3)
s.arrow(1210,690,1210,300,3)
s.text(800,400,'Hot room',30,style='italic')
s.letter(340,680,'A'); s.letter(885,655,'B'); s.letter(760,520,'C'); s.letter(1310,500,'D'); s.letter(1320,160,'E')
s.letter(540,790,'F'); s.letter(130,540,'G'); s.letter(240,800,'H'); s.letter(478,520,'I'); s.letter(1110,500,'J')
s.fill(0,720,1600,900,'#DCC7A8'); s.fill(440,280,1170,560,'#FBF4E8')
s.fill(400,280,440,720,'#E2C9A8'); s.fill(1170,280,1250,720,'#E2C9A8'); s.fill(1175,130,1245,280,'#D6CFC7')
s.save('P4-PM_map2')
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch()
    for f in sorted(glob.glob(os.path.join(TMP,'*.svg'))):
        svg=open(f).read(); w,h=map(int,re.search(r"width='(\d+)' height='(\d+)'",svg).groups())
        pg=b.new_page(viewport={'width':w,'height':h}); pg.set_content(f"<html><body style='margin:0'>{svg}</body></html>")
        pg.screenshot(path=os.path.join(OUT,os.path.basename(f)[:-4]+'.png')); pg.close()
    b.close()
print('drew', len(glob.glob(os.path.join(TMP,'*.svg'))), 'maps into', OUT)
