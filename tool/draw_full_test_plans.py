"""Draw the three plans of the full listening tests (FT01 / FT03 / FT07 Part 2) as exam-style line drawings,
from each test's 'Plan (for the designer)' description.

Output: seed/sources/web_tests/listening/full/FT0N-plan.png (the importer crops these into
assets/listening/maps/lt_wNN_plan.jpg). Uses the Svg helper from tool/draw_listening_maps.py.
usage: python3 tool/draw_full_test_plans.py
"""
import glob, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, 'draw_listening_maps.py')).read()
exec(src[:src.index('PEACH,SAND')])  # Svg class, TMP, F
OUT = os.path.join(os.path.dirname(HERE), 'seed', 'sources', 'web_tests', 'listening', 'full')
GRASS, WATER, WOOD, BUILD, PATH, FIELD, ROOM, STAGE, SEAT = ('#DCEBCF', '#BFE0F0', '#E9DDC6', '#EADBC8', '#F1EBDD',
                                                               '#E8F0D8', '#F3EEE6', '#D9CDBE', '#ECE6F2')


def ell(cx, cy, rx, ry):
    return f"M{cx-rx},{cy} a{rx},{ry} 0 1,0 {2*rx},0 a{rx},{ry} 0 1,0 {-2*rx},0 Z"


# ── FT01 · Brickfield City Farm ─────────────────────────────────────
s = Svg(1200, 1360, 'Brickfield City Farm · Open Day', north=False); s.north(1150, 215)
X1, X2, Y1, Y2 = 100, 1100, 150, 1260
s.fill(X1, Y1, X2, Y2, GRASS)
s.rect(X1, Y1, X2, Y2, 6)
# main path, splitting round the pond
s.fill(570, 790, 630, Y2, PATH)
s.fillpath(ell(600, 700, 200, 140), PATH); s.fillpath(ell(600, 700, 150, 95), GRASS)
s.fill(570, 470, 630, 565, PATH)
s.line(570, 790, 570, Y2, 3); s.line(630, 790, 630, Y2, 3)
s.path(ell(600, 700, 200, 140), 3); s.path(ell(600, 700, 150, 95), 3)
s.fillpath(ell(600, 700, 120, 70), WATER); s.path(ell(600, 700, 120, 70), 3)
s.text(600, 700, 'Duck Pond', 26, style='italic')
s.text(600, 1300, '▲ MAIN ENTRANCE', 26, weight='bold')
s.gap(560, Y2, 640, Y2, 14)
# café
s.fill(200, 1060, 480, 1225, BUILD); s.rect(200, 1060, 480, 1225, 5); s.text(340, 1142, 'Café', 30, weight='bold')
# big barn (NW) with its east door
s.fill(X1, Y1, 420, 420, BUILD); s.rect(X1, Y1, 420, 420, 5); s.text(260, 285, 'Big Barn', 32, weight='bold')
s.gap(420, 300, 420, 360, 8, door=False)
# orchard (NE)
s.fill(780, Y1, X2, 420, WOOD); s.rect(780, Y1, X2, 420, 4, dash='14 8')
for x, y in ((830, 330), (900, 380), (960, 320), (850, 220), (930, 270)):
    s.add(f"<circle cx='{x}' cy='{y}' r='22' fill='#A9C98F' stroke='#3A3A3A' stroke-width='3'/>")
s.text(900, 180, 'Orchard', 30, weight='bold', anchor='middle')
# paddock (E, level with the pond)
s.fill(840, 580, X2, 830, FIELD); s.rect(840, 580, X2, 830, 4, dash='14 8'); s.text(970, 705, 'Paddock', 30, weight='bold')
# small field (SE corner)
s.fill(880, 1040, X2, Y2, FIELD); s.rect(880, 1040, X2, Y2, 4, dash='14 8')
s.letter(540, 930, 'A'); s.letter(690, 1170, 'B'); s.letter(600, 520, 'C'); s.letter(475, 330, 'D')
s.letter(1055, 500, 'E'); s.letter(990, 1150, 'F'); s.letter(1045, 210, 'G'); s.letter(150, 520, 'H'); s.letter(600, 200, 'I')
s.save('FT01-plan')

# ── FT03 · Corran Theatre ground floor ──────────────────────────────
s = Svg(1200, 1520, 'Corran Theatre · Ground Floor', north=False); s.north(1150, 200)
X1, X2, YT, YF, YB = 100, 1100, 130, 860, 1420
s.fill(X1, YF, X2, YB, ROOM)
s.rect(X1, YT, X2, YB, 7)
# auditorium + stage between the corridors
s.fill(330, 210, 870, YF, SEAT); s.fill(330, 210, 870, 340, STAGE)
s.rect(330, 210, 870, YF, 5); s.line(330, 340, 870, 340, 4)
s.text(600, 275, 'STAGE', 30, weight='bold'); s.text(600, 560, 'AUDITORIUM', 34, weight='bold'); s.text(600, 610, '(stalls)', 24, style='italic')
# corridors
s.line(200, 210, 200, 700, 5); s.line(200, 840, 200, YF, 5)
s.line(980, 210, 980, 440, 5); s.line(980, 610, 980, YF, 5)
s.line(200, 210, 980, 210, 5)
s.text(265, 520, 'Left corridor', 22, rot=-90, style='italic'); s.text(925, 520, 'Right corridor', 22, rot=-90, style='italic')
s.line(X1, YF, 330, YF, 5); s.line(870, YF, X2, YF, 5)
s.gap(205, YF, 325, YF, 10, door=False); s.gap(875, YF, 975, YF, 10, door=False)
# rooms off the corridors
s.line(X1, 700, 200, 700, 5); s.line(X1, 840, 200, 840, 5); s.line(200, 700, 200, 840, 5); s.gap(200, 730, 200, 800)
s.line(200, YT, 200, 210, 5); s.line(330, YT, 330, 210, 5); s.gap(230, 210, 300, 210, side=-1)
s.line(870, YT, 870, 210, 5); s.line(980, YT, 980, 210, 5); s.gap(890, 210, 960, 210, side=-1)
s.line(980, 440, X2, 440, 5); s.line(980, 610, X2, 610, 5); s.gap(980, 490, 980, 560, side=1)
# stalls doors either side of the staircase
s.gap(380, YF, 460, YF, 10, door=False); s.gap(740, YF, 820, YF, 10, door=False)
s.text(420, 830, 'Doors', 20); s.text(780, 830, 'Doors', 20)
# grand staircase + room beneath it
s.fill(500, YF, 700, 1000, '#E3D7C3'); s.rect(500, YF, 700, 1000, 4)
for y in range(880, 1000, 20):
    s.line(500, y, 700, y, 2)
s.text(600, 1020, 'Grand Staircase', 22, weight='bold')
s.rect(545, 1040, 655, 1110, 4); s.gap(570, 1110, 630, 1110, side=1)
# bar on the west wall, alcove at its far (north) end
s.fill(X1, 960, 190, 1310, '#E6D3B6'); s.rect(X1, 960, 190, 1310, 4); s.text(145, 1135, 'BAR', 28, weight='bold', rot=-90)
s.line(X1, 960, 200, 960, 3, dash='10 6'); s.line(200, YF, 200, 960, 3, dash='10 6'); s.text(150, 945, 'alcove', 18, style='italic')
# room A south of the bar, left of the entrance
s.rect(X1, 1310, 330, YB, 5); s.gap(330, 1330, 330, 1390, side=1)
# box office + room D on the east wall
s.fill(780, 1300, X2, YB, '#E6D3B6'); s.rect(780, 1300, X2, YB, 5); s.text(940, 1360, 'Box Office', 28, weight='bold')
s.rect(960, 1140, X2, 1300, 5); s.gap(960, 1180, 960, 1250, side=-1)
s.text(600, 1210, 'FOYER', 34, weight='bold')
s.gap(540, YB, 660, YB, 16); s.text(600, 1470, '▲ MAIN ENTRANCE', 26, weight='bold')
s.letter(215, 1365, 'A'); s.letter(150, 770, 'B'); s.letter(265, 170, 'C'); s.letter(1030, 1220, 'D')
s.letter(1040, 525, 'E'); s.letter(600, 1075, 'F', 40); s.letter(925, 170, 'G'); s.letter(150, 900, 'H')
s.save('FT03-plan')

# ── FT07 · Lines on the Land gallery ────────────────────────────────
s = Svg(1400, 1060, 'Lines on the Land · Gallery Plan', north=False); s.north(1360, 225)
X1, X2, Y1, Y2 = 100, 1300, 160, 940
s.fill(X1, Y1, X2, Y2, ROOM); s.rect(X1, Y1, X2, Y2, 7)
s.window(X2, 200, X2, 900, 12); s.text(1345, 550, 'Windows', 24, rot=90, style='italic')
# entrance + ticket desk
s.gap(640, Y2, 760, Y2, 16); s.text(700, 995, '▲ ENTRANCE', 26, weight='bold')
s.fill(775, 820, 930, 890, '#E6D3B6'); s.rect(775, 820, 930, 890, 4); s.text(852, 855, 'Ticket desk', 20, weight='bold')
# globe
s.add("<circle cx='700' cy='560' r='120' fill='#CFE6F2' stroke='#3A3A3A' stroke-width='5'/>")
s.path('M580,560 Q700,500 820,560 M580,560 Q700,620 820,560 M700,440 Q650,560 700,680 M700,440 Q750,560 700,680', 2)
s.text(700, 710, 'Giant Globe', 24, weight='bold')
# staircase NW
s.fill(X1, Y1, 300, 340, '#E3D7C3'); s.rect(X1, Y1, 300, 340, 5)
for x in range(120, 300, 22):
    s.line(x, Y1, x, 340, 2)
s.text(200, 365, 'Staircase', 22, weight='bold')
# shop doorway in the north wall
s.gap(640, Y1, 760, Y1, 12, door=False); s.text(700, 130, 'To shop ▲', 24, weight='bold')
# display cases
for x1, y1, x2, y2 in ((X1, 720, 150, 880), (X1, 470, 150, 630), (320, Y1, 470, 205), (490, Y1, 625, 205),
                       (1130, Y1, X2 - 10, 205), (1240, 470, X2 - 10, 630), (1110, 860, X2 - 10, Y2), (640, 300, 760, 360)):
    s.fill(x1, y1, x2, y2, '#D9CDBE'); s.rect(x1, y1, x2, y2, 3)
s.letter(195, 800, 'A'); s.letter(195, 550, 'B'); s.letter(395, 250, 'C'); s.letter(557, 250, 'D'); s.letter(1215, 250, 'E')
s.letter(1190, 550, 'F'); s.letter(1205, 820, 'G'); s.letter(700, 332, 'H', 44)
s.save('FT07-plan')

from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch()
    for f in sorted(glob.glob(os.path.join(TMP, '*.svg'))):
        svg = open(f).read(); w, h = map(int, re.search(r"width='(\d+)' height='(\d+)'", svg).groups())
        pg = b.new_page(viewport={'width': w, 'height': h}); pg.set_content(f"<html><body style='margin:0'>{svg}</body></html>")
        pg.screenshot(path=os.path.join(OUT, os.path.basename(f)[:-4] + '.png')); pg.close()
    b.close()
print('drew', len(glob.glob(os.path.join(TMP, '*.svg'))), 'plans into', OUT)
