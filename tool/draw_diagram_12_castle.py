from PIL import Image, ImageDraw, ImageFont
S=3; W,H=1024,765
im=Image.new('RGB',(W*S,H*S),'white'); d=ImageDraw.Draw(im)
def T(x,y): return (545+(x-545)*1.1, 600+(y-560)*1.4)
def P(*pts): return [(T(x,y)[0]*S,T(x,y)[1]*S) for x,y in pts]
def R(x0,y0,x1,y1):
    a=T(x0,y0); b=T(x1,y1); return [a[0]*S,a[1]*S,b[0]*S,b[1]*S]
OL=(40,40,40); LW=2*S
STONE=(236,226,212); STONE2=(222,210,194); EARTH=(214,196,170); GRASS=(196,222,176); WATER=(170,206,232); WOOD=(170,120,80)
F=lambda sz,b=False: ImageFont.truetype('/usr/share/fonts/truetype/liberation/LiberationSans-%s.ttf'%('Bold' if b else 'Regular'),sz*S)
GY=560
# ground / earth band
d.polygon(P((290,GY),(800,GY),(800,630),(290,630)),fill=EARTH,outline=OL,width=LW)
# moat (cut into earth)
d.polygon(P((300,GY),(310,600),(330,615),(370,615),(392,600),(402,GY)),fill=WATER,outline=OL,width=LW)
for yy in (580,595):
    d.line(P((322,yy),(335,yy-3),(348,yy),(361,yy-3),(374,yy)),fill=(120,160,200),width=S)
# courtyard grass
d.rectangle(R(560,GY-10,690,GY),fill=GRASS,outline=OL,width=LW)
# merlons helper
def merlons(x0,x1,ytop,h=16,w=12,gap=10):
    x=x0
    while x+w<=x1+0.1:
        d.rectangle(R(x,ytop-h,x+w,ytop),fill=STONE,outline=OL,width=LW); x+=w+gap
# gatehouse
d.rectangle(R(402,380,480,GY),fill=STONE,outline=OL,width=LW); merlons(402,480,380,w=12,gap=10)
# arch + portcullis
d.rectangle(R(422,505,460,GY),fill=(90,80,70))
d.pieslice(R(422,486,460,524),180,360,fill=(90,80,70))
for gx in range(426,460,7): d.line(P((gx,492),(gx,535)),fill=(200,200,200),width=S)
for gy in range(496,536,7): d.line(P((424,gy),(458,gy)),fill=(200,200,200),width=S)
d.line(P((422,505),(422,GY)),fill=OL,width=LW); d.line(P((460,505),(460,GY)),fill=OL,width=LW); d.arc(R(422,486,460,524),180,360,fill=OL,width=LW)
# curtain wall with walkway strip + arrow slits
d.rectangle(R(480,430,560,GY),fill=STONE,outline=OL,width=LW)
d.rectangle(R(480,430,560,442),fill=STONE2,outline=OL,width=LW)   # walkway
merlons(480,560,430,w=12,gap=10)
for sx in (503,530):
    d.rectangle(R(sx,470,sx+5,515),fill=(70,60,55))
# keep
d.rectangle(R(690,250,790,GY),fill=STONE,outline=OL,width=LW); merlons(690,790,250,w=14,gap=8)
for wy in (300,380): d.rectangle(R(737,wy,743,wy+30),fill=(70,60,55))
d.rectangle(R(728,510,752,GY),fill=(90,80,70)); d.pieslice(R(728,498,752,522),180,360,fill=(90,80,70))
# well
d.rectangle(R(598,528,628,GY-10),fill=STONE2,outline=OL,width=LW); d.ellipse(R(596,522,630,534),fill=(150,170,190),outline=OL,width=LW)
d.line(P((600,528),(600,505)),fill=OL,width=LW); d.line(P((626,528),(626,505)),fill=OL,width=LW); d.polygon(P((594,507),(613,494),(632,507)),fill=WOOD,outline=OL,width=LW)
# drawbridge (lowered across the moat) + chains
d.rectangle(R(302,547,404,556),fill=WOOD,outline=OL,width=LW)
for px_ in range(318,404,16): d.line(P((px_,548),(px_,555)),fill=(120,80,50),width=S)
for (ax,ay),(bx,by) in (((308,547),(412,398)),((322,547),(420,404))):
    d.line(P((ax,ay),(bx,by)),fill=(90,90,90),width=S)
# caption
d.text((560*S,715*S),'castle (cross-section from outside to centre)',font=ImageFont.truetype('/usr/share/fonts/truetype/liberation/LiberationSans-Italic.ttf',17*S),fill=(60,60,60),anchor='mm')
# labels + leader lines
TF=F(21); TXT=(45,45,45)
def label(lines,x,y,dot,side):
    for i,t in enumerate(lines):
        d.text((x*S,(y+i*26)*S),t,font=TF,fill=TXT,anchor=('ls' if side=='left' else 'rs'))
    w=max(d.textlength(t,font=TF) for t in lines)/S
    my=y-7+13*(len(lines)-1)
    if side=='left':
        a=(x+w+6,my); b=(x+w+22,my)
    else:
        a=(x-w-6,my); b=(x-w-22,my)
    dt=T(*dot)
    d.line([(a[0]*S,a[1]*S),(b[0]*S,b[1]*S),(dt[0]*S,dt[1]*S)],fill=(60,60,60),width=S+1,joint='curve')
    d.ellipse([ (dt[0]-4)*S,(dt[1]-4)*S,(dt[0]+4)*S,(dt[1]+4)*S],fill=(40,40,40))
B='______'
label(['(5) '+B+': walkway','along the top of the walls'],30,110,(520,436),'left')
label(['curtain wall with','narrow arrow (4) '+B],30,235,(505,492),'left')
label(['gatehouse with iron','grille: the (3) '+B],30,360,(441,512),'left')
label(['(2) '+B+':','raised by chains'],30,480,(365,551),'left')
label(['(1) '+B+':','water-filled ditch'],30,610,(350,600),'left')
label(['(7) '+B+':','massive tower,','the last refuge'],995,250,(760,420),'right')
label(['(6) '+B+':','open courtyard','with a well'],995,470,(660,555),'right')
im=im.resize((W,H),Image.LANCZOS); im.save('diagram_label_12.png')
