"""Writes seed/diagrams/GEMINI_PROMPTS.md: one self-contained image prompt per
Diagram Label set. Label texts come straight from
seed/data/27_reading_bank_passages.json (never retyped); the drawing
description and where each leader line points are written here by hand."""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS = json.load(open(os.path.join(ROOT, 'seed/data/27_reading_bank_passages.json'), encoding='utf-8'))['items']

# subject drawing + pointer target for each label, keyed (side, order)
SPEC = {
 1: ('A simple, clear cross-section of a hand-operated bicycle floor pump standing upright: a T-shaped handle at the top, a straight metal rod going down through the centre of a long vertical cylinder (the barrel), a piston at the bottom end of the rod with a cup-shaped rubber washer round it, a small one-way valve inside the bottom of the barrel, where the air leaves the barrel into the hose (the valve must be clearly visible and separate from the hose), a flexible hose leaving near the base, and a round pressure dial near the base.',
     {('left',1):'the T-shaped handle at the top', ('left',2):'the metal rod running down the centre of the barrel', ('left',3):'the piston at the lower end of the rod',
      ('left',4):'the cup-shaped washer around the piston', ('right',1):'the long outer cylinder (barrel)', ('right',2):'the small valve INSIDE the bottom of the barrel (not the hose)',
      ('right',3):'the flexible hose', ('right',4):'the round pressure dial near the base'}),
 2: ('A cross-section of a main road showing horizontal layers stacked from top to bottom, in this order: a thin dark asphalt surface layer, a thin binder layer, a thicker base layer, a sub-base of crushed stone, and natural soil (subgrade) at the bottom. Layers are clearly separated bands with different textures. The top edge of the road is marked with the small caption "top of road".',
     {('right',1):'the thin top asphalt layer', ('right',2):'the second layer (binder course)', ('right',3):'the third layer (base)',
      ('right',4):'the fourth layer of crushed stone (sub-base)', ('right',5):'the bottom layer of natural soil (subgrade)'}),
 3: ('A side view of a modern wooden beehive made of boxes stacked on top of each other on a stand: from top to bottom — a flat roof with small ventilation gaps, one or two shallow boxes (supers), a thin flat mesh sheet (queen excluder), a deeper box (brood box) with vertical frames visible inside, a mesh floor, a narrow slot entrance at the bottom front, and a stand with legs lifting the hive off the ground. Show one frame partly cut away so a sheet of wax comb is visible.',
     {('left',1):'the roof', ('left',2):'the upper shallow boxes (supers)', ('left',3):'the thin mesh sheet between the supers and the brood box',
      ('left',4):'one of the vertical frames inside a box', ('right',1):'the deep box (brood box)', ('right',2):'the mesh floor',
      ('right',3):'the narrow entrance slot at the bottom front', ('right',4):'the stand with legs'}),
 4: ('A textbook cross-section of the human eye seen from the side, front of the eye on the LEFT: the curved clear cornea at the front, the coloured iris behind it with the pupil opening in its centre, the lens behind the pupil held by small ciliary muscles, the large clear jelly-filled interior (vitreous humour), the retina lining the back wall, and the optic nerve leaving the back on the right.',
     {('left',1):'the cornea (curved clear front surface)', ('left',2):'the iris', ('left',3):'the pupil (gap in the centre of the iris)',
      ('left',4):'the lens', ('right',1):'the small ciliary muscles around the lens', ('right',2):'the jelly-filled interior of the eyeball',
      ('right',3):'the retina lining the back of the eye', ('right',4):'the optic nerve leaving the back of the eye'}),
 5: ('A side view of a traditional brick tower windmill: a tall tapering brick tower, a rotating cap on top, four large sails made of wooden frames and cloth fixed to a windshaft at the front of the cap, a small fantail wheel at the back of the cap, a sack hoist near the top inside, a pair of round millstones on a floor inside the tower (shown in a cut-away), and sacks of flour at the bottom.',
     {('left',1):'the cap on top of the tower', ('left',2):'the four sails', ('left',3):'the windshaft (axle the sails turn on)',
      ('left',4):'the brick tower', ('right',1):'the small fantail wheel at the back of the cap', ('right',2):'the sack hoist near the top inside',
      ('right',3):'the pair of millstones inside the tower', ('right',4):'the sacks of flour at the bottom'}),
 6: ('A vertical soil profile (a cut through the ground) showing six horizontal layers from top to bottom: O horizon (thin layer of leaves and plant litter), A horizon (dark topsoil), E horizon (pale, washed-out layer), B horizon (reddish-brown subsoil), C horizon (broken, weathered rock pieces), R horizon (solid bedrock). A little grass on top; the top edge is marked with the small caption "ground surface".',
     {('right',1):'the top layer of leaves (O horizon)', ('right',2):'the dark topsoil (A horizon)', ('right',3):'the pale layer (E horizon)',
      ('right',4):'the reddish subsoil (B horizon)', ('right',5):'the broken weathered rock (C horizon)', ('right',6):'the solid rock at the bottom (R horizon)'}),
 7: ('A cross-section of a tall cone-shaped stratovolcano: alternating layers of ash and hardened lava in the cone, a bowl-shaped crater at the summit, a tall column of gas, ash and rock rising from the crater, a narrow central pipe (conduit) running from a large magma chamber deep below up to the main vent at the top, a side vent on the slope with a small branch pipe, and lava flows running down the slopes.',
     {('left',1):'the tall eruption column above the crater', ('left',2):'the crater at the summit', ('left',3):'the alternating layers in the cone',
      ('left',4):'the side vent on the slope', ('right',1):'the main vent at the top of the conduit', ('right',2):'the lava flows on the slopes',
      ('right',3):'the narrow central pipe (conduit)', ('right',4):'the large magma chamber deep below'}),
 8: ('A textbook cross-section of human skin with layers from top to bottom: the thin epidermis (flat dead cells at the surface, darker melanocyte cells at its base), the thicker dermis with blood vessels, nerve endings, a coiled sweat gland and a hair growing from a hair follicle, and the hypodermis at the bottom made mostly of rounded fat cells. The top edge is marked with the small caption "skin surface". Next to the epidermis, a small bracket shows its thickness with the note "about 0.1 mm".',
     {('right',1):'the flat dead cells at the very top of the epidermis', ('right',2):'the darker cells at the base of the epidermis', ('right',3):'the dermis layer',
      ('right',4):'the hair follicle and sweat gland in the dermis', ('right',5):'the hypodermis (fat layer) at the bottom', ('right',6):'the fat cells of the hypodermis'}),
 9: ('A textbook cross-section of a leaf, upper surface at the top with sunlight arrows coming from above: from top to bottom — a thin waxy cuticle, the transparent upper epidermis, a row of tall column-shaped palisade cells full of green chloroplasts, a spongy layer of loosely packed round cells with air spaces between them, a vein (bundle with xylem and phloem) in the middle, and the lower epidermis with a stoma (small pore) between two bean-shaped guard cells. The top edge is marked with the small caption "upper surface of leaf (sunlight from above)".',
     {('right',1):'the thin waxy layer on top', ('right',2):'the upper epidermis', ('right',3):'the tall palisade cells',
      ('right',4):'the spongy layer with air spaces', ('right',5):'the vein', ('right',6):'the pore and guard cells in the lower epidermis'}),
 10: ('A cross-section of a hydroelectric dam and power station, water flowing from LEFT to RIGHT: a large reservoir behind a concrete dam on the left, an intake in the dam face covered by a metal grille, a steep pipe (penstock) running down through the dam, a spillway over the top of the dam, a turbine at the bottom of the penstock in the power house with a generator directly above it, a transformer and power lines outside, and a tailrace where water returns to the river on the right.',
     {('left',1):'the reservoir', ('left',2):'the intake grille on the dam face', ('left',3):'the steep pipe through the dam (penstock)',
      ('left',4):'the spillway over the top of the dam', ('right',1):'the generator above the turbine', ('right',2):'the turbine',
      ('right',3):'the transformer outside the power house', ('right',4):'the tailrace returning water to the river'}),
 11: ('A back view of a household refrigerator with the back panel removed, showing its cooling circuit as one closed loop of pipe: the evaporator (inside the food compartment, drawn as a coiled pipe at the top), the pipe carrying refrigerant out of the evaporator, the compressor (a black box-shaped unit at the bottom), the zig-zag condenser coils on the back, the expansion valve (drawn clearly as a small hourglass-shaped valve in the pipe on the way back up to the evaporator), and a small thermostat control. Arrows show the direction of flow round the loop.',
     {('left',1):'the evaporator coil inside the fridge', ('left',2):'the pipe leaving the evaporator towards the compressor', ('left',3):'the small thermostat control',
      ('right',1):'the compressor at the bottom', ('right',2):'the zig-zag condenser coils on the back', ('right',3):'the small hourglass-shaped expansion valve in the pipe'}),
 12: ('A FLAT 2D side-on cross-section (profile) of a thirteenth-century stone castle — NOT a 3D or bird\'s-eye view. Read from the OUTSIDE on the left to the CENTRE on the right, all parts in one horizontal row on the same ground line: (a) a water-filled moat (a dip in the ground filled with blue water) on the far left; (b) a wooden drawbridge lowered across the moat, with two chains running up to the gatehouse; (c) a gatehouse with an arched gateway, an iron grille (portcullis, drawn as a criss-cross grid) half-lowered in the arch; (d) a high curtain wall joined to the gatehouse, with two or three narrow vertical arrow slits; (e) battlements: a walkway with a notched parapet along the top of the curtain wall and gatehouse; (f) an open grassy courtyard (bailey) with a small round stone well; (g) a massive tall square tower (keep) on the far right. Keep plenty of space between the parts so each leader line can reach its part clearly.',
     {('left',1):'the blue water of the moat', ('left',2):'the wooden drawbridge lying across the moat', ('left',3):'the iron grille (portcullis) in the gateway arch',
      ('left',4):'one arrow slit in the curtain wall', ('right',1):'the walkway behind the notched parapet on top of the wall', ('right',2):'the open grass of the courtyard (not the well)',
      ('right',3):'the massive tower at the centre'}),
 13: ('A map-like view from above of a valley glacier flowing from LEFT to RIGHT between mountains: an armchair-shaped hollow (cirque) at the head on the left, the accumulation zone (upper part, white snow), deep crevasses crossing the ice, ridges of rock along both edges (lateral moraines), the ablation zone (lower part, greyer ice), the snout (front edge of the ice) on the right, and a curved ridge of rock beyond it (terminal moraine).',
     {('left',1):'the armchair-shaped hollow at the head of the glacier', ('left',2):'the upper, snow-covered part of the glacier', ('left',3):'the cracks across the ice',
      ('left',4):'the rock ridge along the edge of the glacier', ('right',1):'the lower, greyer part of the glacier', ('right',2):'the front edge of the ice',
      ('right',3):'the curved rock ridge beyond the front edge'}),
 14: ('A tree trunk cut straight across, seen face-on as a disc, with concentric rings from outside to centre: rough dark outer bark, a thin inner layer (phloem), a very thin line (cambium), a wide pale band of sapwood, a darker central area of heartwood, and a small soft pith at the very centre. Clear growth rings are visible in the wood. The small caption "trunk cut across" appears under the disc.',
     {('left',1):'the rough outer bark', ('left',2):'the thin layer just inside the bark', ('left',3):'the very thin line between that layer and the pale wood',
      ('right',1):'the wide pale band of wood', ('right',2):'the dark central wood', ('right',3):'the small soft centre',
      ('right',4):'one single growth ring'}),
 15: ('A textbook front view of the human heart (as seen facing a person, so the heart\'s RIGHT side appears on the LEFT of the picture), with the front wall cut away to show the four chambers: right atrium (upper left of picture) with a small pacemaker area in its wall, right ventricle (lower left), left atrium (upper right), left ventricle (lower right) with a noticeably thicker wall, the septum (thick wall dividing left and right), the tricuspid valve between right atrium and right ventricle, the aorta arching over the top, and the pulmonary artery leaving the right ventricle towards the lungs.',
     {('left',1):'the pulmonary artery', ('left',2):'the small pacemaker area in the wall of the right atrium', ('left',3):'the valve between right atrium and right ventricle',
      ('left',4):'the right ventricle', ('right',1):'the aorta', ('right',2):'the left atrium',
      ('right',3):'the thick dividing wall (septum)', ('right',4):'the left ventricle'}),
 16: ('A cross-section of a turbofan jet engine drawn horizontally, FRONT (air intake) on the LEFT: a very large fan at the front, air flowing around the outside of the core (bypass air, shown with arrows), the compressor with many small blades, the combustion chamber with flames, the turbine blades behind it, a central shaft connecting the turbine to the fan and compressor, and the exhaust nozzle at the back on the right where hot gases leave.',
     {('left',1):'the large fan at the front', ('left',2):'the arrows of air flowing around the core', ('left',3):'the same bypass air flow (a second line to it)',
      ('left',4):'the compressor', ('right',1):'the combustion chamber', ('right',2):'the central shaft',
      ('right',3):'the exhaust nozzle at the back'}),
 17: ('A tall vertical diagram of the layers of Earth\'s atmosphere (not to scale): the Earth\'s surface curve at the bottom with clouds and mountains, then five horizontal bands from bottom to top — troposphere (with clouds and weather), stratosphere (with an ozone layer band and a passenger plane at its base), mesosphere (with a meteor streak burning up), thermosphere (with auroras and a small space station), exosphere fading into black space with stars. The top edge is marked with the small caption "outer edge of the atmosphere".',
     {('right',1):'the top band fading into space (exosphere)', ('right',2):'the fourth band with auroras (thermosphere)', ('right',3):'the third band with the meteor (mesosphere)',
      ('right',4):'the second band with the ozone layer (stratosphere)', ('right',5):'the lowest band with clouds (troposphere)'}),
 18: ('A cross-section of a completed, sealed landfill cell, layers from top to bottom: grass on topsoil, a clay cap, the waste in layers (each thin layer covered with soil) with vertical gas wells rising through it, a gravel drainage layer at the bottom with perforated pipes, a plastic liner under the gravel, a thick layer of compacted clay, and natural ground with a monitoring well going down into it at the side. The top edge is marked with the small caption "surface of the completed site".',
     {('right',1):'the grass and topsoil on top', ('right',2):'the clay cap', ('right',3):'the waste layers with thin soil covers',
      ('right',4):'the vertical gas wells in the waste', ('right',5):'the gravel layer with pipes', ('right',6):'the plastic liner',
      ('right',7):'the compacted clay layer', ('right',8):'the natural ground and monitoring well'}),
 19: ('A textbook cross-section of the human ear from outside (LEFT) to inside (RIGHT), with the three regions marked lightly as outer, middle and inner ear: the pinna (outer ear flap), the ear canal, the eardrum, the three tiny ossicle bones in the middle ear, the Eustachian tube going down from the middle ear, the three looped semicircular canals, the snail-shaped cochlea, and the auditory nerve leaving towards the brain.',
     {('left',1):'the outer ear flap (pinna)', ('left',2):'the ear canal', ('left',3):'the eardrum',
      ('left',4):'the three tiny bones in the middle ear', ('right',1):'the three looped canals', ('right',2):'the snail-shaped cochlea',
      ('right',3):'the auditory nerve', ('right',4):'the tube going down from the middle ear'}),
 20: ('A side view of a modern three-bladed wind turbine: a tall hollow steel tower on a concrete foundation shown below ground level, a nacelle (housing) on top with a cut-away showing the gearbox and a yaw drive at its base, a central hub at the front with three long blades and a pitch mechanism at the blade roots, and an anemometer and wind vane on top of the nacelle at the back.',
     {('left',1):'one of the three long blades', ('left',2):'the pitch mechanism at the root of a blade', ('left',3):'the central hub',
      ('left',4):'the gearbox inside the nacelle', ('right',1):'the nacelle (housing)', ('right',2):'the anemometer and wind vane on top of the nacelle',
      ('right',3):'the yaw drive at the base of the nacelle', ('right',4):'the tall tower', ('right',5):'the concrete foundation below ground'}),
}

# display order overrides (side -> source 'order' values, top to bottom) where the
# source order fights the drawing (e.g. the compressor sits at the bottom of a fridge)
ORDER_OVERRIDE = {11: {'right': [2, 3, 1]}}

STYLE = ('Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), '
         'flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. '
         'Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Put labels ONLY in the left and right margins exactly as listed — never above or below the drawing, and never write a label twice (not even a shortened copy). Every label must have its own leader line.')
TEXT = ('Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given '
        'between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, '
        'translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, '
        'no answers, no watermark.')

def label_block(g):
    return g

out = ['# Gemini image prompts — Reading "Diagram Label Completion" sets', '',
       'One prompt per diagram. Copy the whole grey block into Gemini (image generation). '
       'Label texts are copied automatically from `seed/data/27_reading_bank_passages.json`, so they match the questions exactly.', '',
       '## How to use', '',
       '1. Paste one prompt into Gemini and generate.',
       '2. If anything is wrong, the safest fix is to start a **new chat** and paste the same prompt again (Gemini edits tend to ADD a corrected copy instead of replacing the wrong part). If you do edit in the same chat, always say what to remove and repeat the label count, e.g.:',
       '   - wrong text: *"Change the text of the label \"…\" to exactly \"…\". Do not add any new label. The image must still have exactly N labels."*',
       '   - wrong line: *"Move the EXISTING leader line of the label \"…\" so it ends on …. Do not add a new label or a new line. The image must still have exactly N labels, each text once."*',
       '   - duplicate label: *"Delete the duplicate label \"…\" (the one pointing to …) and its line. Change nothing else."*',
       '3. Check the image with the checklist under each prompt — count the labels and follow every line to its end.',
       '4. Save as PNG (or SVG if you redraw it) with the file name given, in `assets/diagrams/`.',
       '5. If Gemini keeps garbling the text, use the **No-text fallback** at the end of each prompt: generate the drawing without any text, then add the labels yourself in Canva/Figma.',
       '', 'Never let an answer appear on the image — the blanks must stay blank.', '']
for it in ITEMS:
    if it['questionType'] != 'diagram_label':
        continue
    n = it['bankSet']
    g = next(g for g in it['groups'] if g['type'] == 'diagram')
    desc, targets = SPEC[n]
    labs = sorted(g['labels'], key=lambda l: (0 if l['side'] == 'left' else 1, l['order']))
    for l in labs:
        assert (l['side'], l['order']) in targets, (n, l)
    assert len(targets) == len(labs), n
    fname = f'diagram_label_{n:02d}.png'
    lines = [f'## {n:02d} · {g["title"]}  ({it["difficulty"]})', '',
             f'File: `{fname}` · Passage: "{it["title"]}" · Questions {g["questions"][0]["number"]}–{g["questions"][-1]["number"]}', '', '```']
    lines.append(f'Draw an educational diagram titled (do NOT write the title): {g["title"]}.')
    lines.append('')
    lines.append(desc)
    lines.append('')
    for side in ('left', 'right'):
        ls = [l for l in labs if l['side'] == side]
        ov = ORDER_OVERRIDE.get(n, {}).get(side)
        if ov:
            ls = sorted(ls, key=lambda l: ov.index(l['order']))
        if not ls:
            continue
        lines.append(f'Labels on the {side.upper()} side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:')
        for k, l in enumerate(ls, 1):
            lines.append(f'  {k}. "{l["text"]}"  → points to {targets[(side, l["order"])]}')
        lines.append('')
    extra = []
    cap = g.get('caption')
    if cap:
        extra.append(f'Small italic caption placed on or next to the drawing: "{cap}".')
    for a in g.get('annotations') or []:
        extra.append(f'Small note next to the drawing: "{a}".')
    if extra:
        lines += extra + ['']
    lines.append(f'Count check: the finished image has EXACTLY {len(labs)} labels and {len(labs)} leader lines — each label text appears only once, and no two lines end on the same part.')
    lines.append('')
    lines += [STYLE, TEXT, '```', '', '**Checklist:** ' +
              f'{len(labs)} labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · '
              'every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.', '',
              '<details><summary>No-text fallback</summary>', '', '```',
              f'Same drawing as described: {desc} {STYLE} Draw NO text at all. Instead, end each leader line in an empty small circle '
              f'at the {"left and right margins" if len({l["side"] for l in labs}) == 2 else labs[0]["side"] + " margin"}, '
              f'{len(labs)} circles in total, placed where the labels will go.', '```', '', '</details>', '']
    out += lines
open(os.path.join(ROOT, 'seed/diagrams/GEMINI_PROMPTS.md'), 'w', encoding='utf-8').write('\n'.join(out))
print('ok', sum(1 for i in ITEMS if i['questionType'] == 'diagram_label'))
