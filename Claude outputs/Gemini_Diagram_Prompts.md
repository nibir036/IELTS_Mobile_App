# Gemini image prompts — Reading "Diagram Label Completion" sets

One prompt per diagram. Copy the whole grey block into Gemini (image generation). Label texts are copied automatically from `seed/data/27_reading_bank_passages.json`, so they match the questions exactly.

## How to use

1. Paste one prompt into Gemini and generate.
2. If anything is wrong, the safest fix is to start a **new chat** and paste the same prompt again (Gemini edits tend to ADD a corrected copy instead of replacing the wrong part). If you do edit in the same chat, always say what to remove and repeat the label count, e.g.:
   - wrong text: *"Change the text of the label "…" to exactly "…". Do not add any new label. The image must still have exactly N labels."*
   - wrong line: *"Move the EXISTING leader line of the label "…" so it ends on …. Do not add a new label or a new line. The image must still have exactly N labels, each text once."*
   - duplicate label: *"Delete the duplicate label "…" (the one pointing to …) and its line. Change nothing else."*
3. Check the image with the checklist under each prompt — count the labels and follow every line to its end.
4. Save as PNG (or SVG if you redraw it) with the file name given, in `assets/diagrams/`.
5. If Gemini keeps garbling the text, use the **No-text fallback** at the end of each prompt: generate the drawing without any text, then add the labels yourself in Canva/Figma.

Never let an answer appear on the image — the blanks must stay blank.

## 01 · A bicycle pump  (easy)

File: `diagram_label_01.png` · Passage: "Under Pressure" · Questions 1–6

```
Draw an educational diagram titled (do NOT write the title): A bicycle pump.

A simple, clear cross-section of a hand-operated bicycle floor pump standing upright: a T-shaped handle at the top, a straight metal rod going down through the centre of a long vertical cylinder (the barrel), a piston at the bottom end of the rod with a cup-shaped rubber washer round it, a small one-way valve inside the bottom of the barrel, where the air leaves the barrel into the hose (the valve must be clearly visible and separate from the hose), a flexible hose leaving near the base, and a round pressure dial near the base.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "handle"  → points to the T-shaped handle at the top
  2. "metal (1) ______ running down the centre"  → points to the metal rod running down the centre of the barrel
  3. "piston"  → points to the piston at the lower end of the rod
  4. "(2) ______ of rubber or leather forms a seal"  → points to the cup-shaped washer around the piston

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(3) ______: long outer tube"  → points to the long outer cylinder (barrel)
  2. "one-way (4) ______"  → points to the small valve INSIDE the bottom of the barrel (not the hose)
  3. "flexible (5) ______ carries air to the tyre"  → points to the flexible hose
  4. "(6) ______: dial showing tyre pressure"  → points to the round pressure dial near the base

Small italic caption placed on or next to the drawing: "bicycle pump (cross-section)".

Count check: the finished image has EXACTLY 8 labels and 8 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 8 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A simple, clear cross-section of a hand-operated bicycle floor pump standing upright: a T-shaped handle at the top, a straight metal rod going down through the centre of a long vertical cylinder (the barrel), a piston at the bottom end of the rod with a cup-shaped rubber washer round it, a small one-way valve inside the bottom of the barrel, where the air leaves the barrel into the hose (the valve must be clearly visible and separate from the hose), a flexible hose leaving near the base, and a round pressure dial near the base. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 8 circles in total, placed where the labels will go.
```

</details>

## 02 · Cross-section of a main road  (easy)

File: `diagram_label_02.png` · Passage: "More Than Meets the Eye" · Questions 1–6

```
Draw an educational diagram titled (do NOT write the title): Cross-section of a main road.

A cross-section of a main road showing horizontal layers stacked from top to bottom, in this order: a thin dark asphalt surface layer, a thin binder layer, a thicker base layer, a sub-base of crushed stone, and natural soil (subgrade) at the bottom. Layers are clearly separated bands with different textures. The top edge of the road is marked with the small caption "top of road".

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "surface course: smooth asphalt, about (1) ______ mm thick"  → points to the thin top asphalt layer
  2. "(2) ______ course: bonds the surface to the base"  → points to the second layer (binder course)
  3. "base: spreads the (3) ______ of traffic"  → points to the third layer (base)
  4. "sub-base: crushed (4) ______; allows water to (5) ______"  → points to the fourth layer of crushed stone (sub-base)
  5. "subgrade: natural (6) ______, levelled and compacted"  → points to the bottom layer of natural soil (subgrade)

Small italic caption placed on or next to the drawing: "top of road".

Count check: the finished image has EXACTLY 5 labels and 5 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 5 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A cross-section of a main road showing horizontal layers stacked from top to bottom, in this order: a thin dark asphalt surface layer, a thin binder layer, a thicker base layer, a sub-base of crushed stone, and natural soil (subgrade) at the bottom. Layers are clearly separated bands with different textures. The top edge of the road is marked with the small caption "top of road". Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the right margin, 5 circles in total, placed where the labels will go.
```

</details>

## 03 · A modern beehive  (easy)

File: `diagram_label_03.png` · Passage: "A House for Bees" · Questions 1–6

```
Draw an educational diagram titled (do NOT write the title): A modern beehive.

A side view of a modern wooden beehive made of boxes stacked on top of each other on a stand: from top to bottom — a flat roof with small ventilation gaps, one or two shallow boxes (supers), a thin flat mesh sheet (queen excluder), a deeper box (brood box) with vertical frames visible inside, a mesh floor, a narrow slot entrance at the bottom front, and a stand with legs lifting the hive off the ground. Show one frame partly cut away so a sheet of wax comb is visible.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "roof: gaps provide (1) ______"  → points to the roof
  2. "supers: where bees store (2) ______"  → points to the upper shallow boxes (supers)
  3. "queen excluder: stops the (3) ______ from entering the supers"  → points to the thin mesh sheet between the supers and the brood box
  4. "frames each hold a sheet of (4) ______"  → points to one of the vertical frames inside a box

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "brood box: where (5) ______ are laid"  → points to the deep box (brood box)
  2. "mesh floor: mites fall through"  → points to the mesh floor
  3. "(6) ______: made narrower in winter"  → points to the narrow entrance slot at the bottom front
  4. "stand: keeps hive off damp ground"  → points to the stand with legs

Small italic caption placed on or next to the drawing: "beehive (side view, boxes stacked)".

Count check: the finished image has EXACTLY 8 labels and 8 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 8 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A side view of a modern wooden beehive made of boxes stacked on top of each other on a stand: from top to bottom — a flat roof with small ventilation gaps, one or two shallow boxes (supers), a thin flat mesh sheet (queen excluder), a deeper box (brood box) with vertical frames visible inside, a mesh floor, a narrow slot entrance at the bottom front, and a stand with legs lifting the hive off the ground. Show one frame partly cut away so a sheet of wax comb is visible. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 8 circles in total, placed where the labels will go.
```

</details>

## 04 · The human eye  (easy)

File: `diagram_label_04.png` · Passage: "Windows on the World" · Questions 1–6

```
Draw an educational diagram titled (do NOT write the title): The human eye.

A textbook cross-section of the human eye seen from the side, front of the eye on the LEFT: the curved clear cornea at the front, the coloured iris behind it with the pupil opening in its centre, the lens behind the pupil held by small ciliary muscles, the large clear jelly-filled interior (vitreous humour), the retina lining the back wall, and the optic nerve leaving the back on the right.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(1) ______: clear front surface that bends light"  → points to the cornea (curved clear front surface)
  2. "iris"  → points to the iris
  3. "(2) ______: opening in the centre of the iris"  → points to the pupil (gap in the centre of the iris)
  4. "(3) ______: fine-tunes the focus"  → points to the lens

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "ciliary (4) ______: change the shape of the lens"  → points to the small ciliary muscles around the lens
  2. "vitreous humour"  → points to the jelly-filled interior of the eyeball
  3. "(5) ______: light-sensitive layer at the back"  → points to the retina lining the back of the eye
  4. "optic (6) ______: carries signals to the brain"  → points to the optic nerve leaving the back of the eye

Small italic caption placed on or next to the drawing: "eye (cross-section)".

Count check: the finished image has EXACTLY 8 labels and 8 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 8 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A textbook cross-section of the human eye seen from the side, front of the eye on the LEFT: the curved clear cornea at the front, the coloured iris behind it with the pupil opening in its centre, the lens behind the pupil held by small ciliary muscles, the large clear jelly-filled interior (vitreous humour), the retina lining the back wall, and the optic nerve leaving the back on the right. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 8 circles in total, placed where the labels will go.
```

</details>

## 05 · A tower windmill  (easy)

File: `diagram_label_05.png` · Passage: "Harnessing the Wind" · Questions 1–6

```
Draw an educational diagram titled (do NOT write the title): A tower windmill.

A side view of a traditional brick tower windmill: a tall tapering brick tower, a rotating cap on top, four large sails made of wooden frames and cloth fixed to a windshaft at the front of the cap, a small fantail wheel at the back of the cap, a sack hoist near the top inside, a pair of round millstones on a floor inside the tower (shown in a cut-away), and sacks of flour at the bottom.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(1) ______: rotates so sails face the wind"  → points to the cap on top of the tower
  2. "four (2) ______ of wood and cloth"  → points to the four sails
  3. "windshaft"  → points to the windshaft (axle the sails turn on)
  4. "brick tower: up to (3) ______ storeys high"  → points to the brick tower

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(4) ______: small wheel at the back of the cap"  → points to the small fantail wheel at the back of the cap
  2. "sack (5) ______ lifts grain to the top"  → points to the sack hoist near the top inside
  3. "pair of (6) ______ grind the grain"  → points to the pair of millstones inside the tower
  4. "flour collected in sacks"  → points to the sacks of flour at the bottom

Small italic caption placed on or next to the drawing: "tower mill (side view)".

Count check: the finished image has EXACTLY 8 labels and 8 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 8 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A side view of a traditional brick tower windmill: a tall tapering brick tower, a rotating cap on top, four large sails made of wooden frames and cloth fixed to a windshaft at the front of the cap, a small fantail wheel at the back of the cap, a sack hoist near the top inside, a pair of round millstones on a floor inside the tower (shown in a cut-away), and sacks of flour at the bottom. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 8 circles in total, placed where the labels will go.
```

</details>

## 06 · A soil profile  (easy)

File: `diagram_label_06.png` · Passage: "Beneath Our Feet" · Questions 1–6

```
Draw an educational diagram titled (do NOT write the title): A soil profile.

A vertical soil profile (a cut through the ground) showing six horizontal layers from top to bottom: O horizon (thin layer of leaves and plant litter), A horizon (dark topsoil), E horizon (pale, washed-out layer), B horizon (reddish-brown subsoil), C horizon (broken, weathered rock pieces), R horizon (solid bedrock). A little grass on top; the top edge is marked with the small caption "ground surface".

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "O horizon: leaves and other (1) ______ matter"  → points to the top layer of leaves (O horizon)
  2. "A horizon (topsoil): dark colour from (2) ______"  → points to the dark topsoil (A horizon)
  3. "E horizon: minerals (3) ______ by rainwater"  → points to the pale layer (E horizon)
  4. "B horizon (subsoil): (4) ______ and iron collect"  → points to the reddish subsoil (B horizon)
  5. "C horizon: weathered parent (5) ______"  → points to the broken weathered rock (C horizon)
  6. "R horizon: (6) ______"  → points to the solid rock at the bottom (R horizon)

Small italic caption placed on or next to the drawing: "ground surface".

Count check: the finished image has EXACTLY 6 labels and 6 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 6 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A vertical soil profile (a cut through the ground) showing six horizontal layers from top to bottom: O horizon (thin layer of leaves and plant litter), A horizon (dark topsoil), E horizon (pale, washed-out layer), B horizon (reddish-brown subsoil), C horizon (broken, weathered rock pieces), R horizon (solid bedrock). A little grass on top; the top edge is marked with the small caption "ground surface". Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the right margin, 6 circles in total, placed where the labels will go.
```

</details>

## 07 · Cross-section of a stratovolcano  (medium)

File: `diagram_label_07.png` · Passage: "Mountains of Fire" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): Cross-section of a stratovolcano.

A cross-section of a tall cone-shaped stratovolcano: alternating layers of ash and hardened lava in the cone, a bowl-shaped crater at the summit, a tall column of gas, ash and rock rising from the crater, a narrow central pipe (conduit) running from a large magma chamber deep below up to the main vent at the top, a side vent on the slope with a small branch pipe, and lava flows running down the slopes.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(1) ______: gas, ash and rock rising over 20 km"  → points to the tall eruption column above the crater
  2. "(2) ______: bowl-shaped hollow at the summit"  → points to the crater at the summit
  3. "alternating layers of ash and (3) ______"  → points to the alternating layers in the cone
  4. "(4) ______: magma escapes on the slope"  → points to the side vent on the slope

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "main vent"  → points to the main vent at the top of the conduit
  2. "(5) ______: move slowly down the slopes"  → points to the lava flows on the slopes
  3. "(6) ______: narrow pipe for rising magma"  → points to the narrow central pipe (conduit)
  4. "(7) ______: 1–10 km below the surface"  → points to the large magma chamber deep below

Small italic caption placed on or next to the drawing: "stratovolcano (cross-section)".

Count check: the finished image has EXACTLY 8 labels and 8 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 8 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A cross-section of a tall cone-shaped stratovolcano: alternating layers of ash and hardened lava in the cone, a bowl-shaped crater at the summit, a tall column of gas, ash and rock rising from the crater, a narrow central pipe (conduit) running from a large magma chamber deep below up to the main vent at the top, a side vent on the slope with a small branch pipe, and lava flows running down the slopes. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 8 circles in total, placed where the labels will go.
```

</details>

## 08 · Cross-section of human skin  (medium)

File: `diagram_label_08.png` · Passage: "The Body's Largest Organ" · Questions 1–6

```
Draw an educational diagram titled (do NOT write the title): Cross-section of human skin.

A textbook cross-section of human skin with layers from top to bottom: the thin epidermis (flat dead cells at the surface, darker melanocyte cells at its base), the thicker dermis with blood vessels, nerve endings, a coiled sweat gland and a hair growing from a hair follicle, and the hypodermis at the bottom made mostly of rounded fat cells. The top edge is marked with the small caption "skin surface". Next to the epidermis, a small bracket shows its thickness with the note "about 0.1 mm".

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "epidermis (surface): (1) ______ cells filled with keratin"  → points to the flat dead cells at the very top of the epidermis
  2. "epidermis (base): (2) ______ produce melanin"  → points to the darker cells at the base of the epidermis
  3. "(3) ______: collagen, blood vessels, nerve endings"  → points to the dermis layer
  4. "dermis: sweat glands and hair (4) ______"  → points to the hair follicle and sweat gland in the dermis
  5. "(5) ______: made up mainly of fat"  → points to the hypodermis (fat layer) at the bottom
  6. "hypodermis: insulates, protects and stores (6) ______"  → points to the fat cells of the hypodermis

Small italic caption placed on or next to the drawing: "skin surface".
Small note next to the drawing: "about 0.1 mm".

Count check: the finished image has EXACTLY 6 labels and 6 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 6 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A textbook cross-section of human skin with layers from top to bottom: the thin epidermis (flat dead cells at the surface, darker melanocyte cells at its base), the thicker dermis with blood vessels, nerve endings, a coiled sweat gland and a hair growing from a hair follicle, and the hypodermis at the bottom made mostly of rounded fat cells. The top edge is marked with the small caption "skin surface". Next to the epidermis, a small bracket shows its thickness with the note "about 0.1 mm". Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the right margin, 6 circles in total, placed where the labels will go.
```

</details>

## 09 · Cross-section of a leaf  (medium)

File: `diagram_label_09.png` · Passage: "A Factory in Every Leaf" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): Cross-section of a leaf.

A textbook cross-section of a leaf, upper surface at the top with sunlight arrows coming from above: from top to bottom — a thin waxy cuticle, the transparent upper epidermis, a row of tall column-shaped palisade cells full of green chloroplasts, a spongy layer of loosely packed round cells with air spaces between them, a vein (bundle with xylem and phloem) in the middle, and the lower epidermis with a stoma (small pore) between two bean-shaped guard cells. The top edge is marked with the small caption "upper surface of leaf (sunlight from above)".

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "waxy (1) ______: reduces water loss"  → points to the thin waxy layer on top
  2. "upper epidermis: thin and (2) ______"  → points to the upper epidermis
  3. "palisade layer: tall cells packed with (3) ______"  → points to the tall palisade cells
  4. "spongy layer: (4) ______ allow gases to move"  → points to the spongy layer with air spaces
  5. "vein: xylem carries (5) ______; phloem carries sugar"  → points to the vein
  6. "lower epidermis: (6) ______, opened and closed by (7) ______"  → points to the pore and guard cells in the lower epidermis

Small italic caption placed on or next to the drawing: "upper surface of leaf (sunlight from above)".

Count check: the finished image has EXACTLY 6 labels and 6 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 6 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A textbook cross-section of a leaf, upper surface at the top with sunlight arrows coming from above: from top to bottom — a thin waxy cuticle, the transparent upper epidermis, a row of tall column-shaped palisade cells full of green chloroplasts, a spongy layer of loosely packed round cells with air spaces between them, a vein (bundle with xylem and phloem) in the middle, and the lower epidermis with a stoma (small pore) between two bean-shaped guard cells. The top edge is marked with the small caption "upper surface of leaf (sunlight from above)". Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the right margin, 6 circles in total, placed where the labels will go.
```

</details>

## 10 · A hydroelectric power station  (medium)

File: `diagram_label_10.png` · Passage: "Power from Falling Water" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): A hydroelectric power station.

A cross-section of a hydroelectric dam and power station, water flowing from LEFT to RIGHT: a large reservoir behind a concrete dam on the left, an intake in the dam face covered by a metal grille, a steep pipe (penstock) running down through the dam, a spillway over the top of the dam, a turbine at the bottom of the penstock in the power house with a generator directly above it, a transformer and power lines outside, and a tailrace where water returns to the river on the right.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(1) ______: artificial lake behind the dam"  → points to the reservoir
  2. "intake protected by a metal (2) ______"  → points to the intake grille on the dam face
  3. "(3) ______: steep pipe"  → points to the steep pipe through the dam (penstock)
  4. "(4) ______: releases excess water during floods"  → points to the spillway over the top of the dam

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(5) ______: magnets rotate within copper coils"  → points to the generator above the turbine
  2. "turbine"  → points to the turbine
  3. "transformer increases the (6) ______"  → points to the transformer outside the power house
  4. "(7) ______: water returns to the river"  → points to the tailrace returning water to the river

Small italic caption placed on or next to the drawing: "dam and power station (cross-section)".

Count check: the finished image has EXACTLY 8 labels and 8 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 8 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A cross-section of a hydroelectric dam and power station, water flowing from LEFT to RIGHT: a large reservoir behind a concrete dam on the left, an intake in the dam face covered by a metal grille, a steep pipe (penstock) running down through the dam, a spillway over the top of the dam, a turbine at the bottom of the penstock in the power house with a generator directly above it, a transformer and power lines outside, and a tailrace where water returns to the river on the right. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 8 circles in total, placed where the labels will go.
```

</details>

## 11 · How a refrigerator works  (medium)

File: `diagram_label_11.png` · Passage: "Moving Heat" · Questions 1–6

```
Draw an educational diagram titled (do NOT write the title): How a refrigerator works.

A back view of a household refrigerator with the back panel removed, showing its cooling circuit as one closed loop of pipe: the evaporator (inside the food compartment, drawn as a coiled pipe at the top), the pipe carrying refrigerant out of the evaporator, the compressor (a black box-shaped unit at the bottom), the zig-zag condenser coils on the back, the expansion valve (a narrow point in the pipe) returning to the evaporator, and a small thermostat control. Arrows show the direction of flow round the loop.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "evaporator: refrigerant (1) ______ heat from the food"  → points to the evaporator coil inside the fridge
  2. "refrigerant becomes a (2) ______"  → points to the pipe leaving the evaporator towards the compressor
  3. "(3) ______: switches the compressor on and off"  → points to the small thermostat control

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "compressor: raises the (4) ______ of the gas"  → points to the compressor at the bottom
  2. "condenser coils: heat is (5) ______ into the kitchen"  → points to the zig-zag condenser coils on the back
  3. "expansion valve: pressure (6) ______ suddenly"  → points to the expansion valve (narrow point in the pipe)

Small italic caption placed on or next to the drawing: "refrigerator (back view)".

Count check: the finished image has EXACTLY 6 labels and 6 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 6 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A back view of a household refrigerator with the back panel removed, showing its cooling circuit as one closed loop of pipe: the evaporator (inside the food compartment, drawn as a coiled pipe at the top), the pipe carrying refrigerant out of the evaporator, the compressor (a black box-shaped unit at the bottom), the zig-zag condenser coils on the back, the expansion valve (a narrow point in the pipe) returning to the evaporator, and a small thermostat control. Arrows show the direction of flow round the loop. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 6 circles in total, placed where the labels will go.
```

</details>

## 12 · The defences of a thirteenth-century castle  (medium)

File: `diagram_label_12.png` · Passage: "Built for War" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): The defences of a thirteenth-century castle.

A cross-section of a thirteenth-century stone castle, from the OUTSIDE on the left to the CENTRE on the right: a water-filled moat, a wooden drawbridge raised by chains, a gatehouse with an iron grille (portcullis) in its archway, a high curtain wall with narrow arrow slits, battlements (a walkway with notched parapet) along the top of the walls, an open courtyard (bailey) with a well, and a massive tall tower (keep) at the centre on the right.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(1) ______: water-filled ditch"  → points to the moat
  2. "(2) ______: raised by chains"  → points to the drawbridge
  3. "gatehouse with iron grille: the (3) ______"  → points to the gatehouse with its iron grille
  4. "curtain wall with narrow arrow (4) ______"  → points to the curtain wall with arrow slits

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(5) ______: walkway along the top of the walls"  → points to the walkway along the top of the walls
  2. "(6) ______: open courtyard with a well"  → points to the open courtyard with the well
  3. "(7) ______: massive tower, the last refuge"  → points to the massive tower at the centre

Small italic caption placed on or next to the drawing: "castle (cross-section from outside to centre)".

Count check: the finished image has EXACTLY 7 labels and 7 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 7 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A cross-section of a thirteenth-century stone castle, from the OUTSIDE on the left to the CENTRE on the right: a water-filled moat, a wooden drawbridge raised by chains, a gatehouse with an iron grille (portcullis) in its archway, a high curtain wall with narrow arrow slits, battlements (a walkway with notched parapet) along the top of the walls, an open courtyard (bailey) with a well, and a massive tall tower (keep) at the centre on the right. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 7 circles in total, placed where the labels will go.
```

</details>

## 13 · Features of a valley glacier  (medium)

File: `diagram_label_13.png` · Passage: "Rivers of Ice" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): Features of a valley glacier.

A map-like view from above of a valley glacier flowing from LEFT to RIGHT between mountains: an armchair-shaped hollow (cirque) at the head on the left, the accumulation zone (upper part, white snow), deep crevasses crossing the ice, ridges of rock along both edges (lateral moraines), the ablation zone (lower part, greyer ice), the snout (front edge of the ice) on the right, and a curved ridge of rock beyond it (terminal moraine).

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(1) ______: armchair-shaped hollow"  → points to the armchair-shaped hollow at the head of the glacier
  2. "accumulation zone: more (2) ______ than melts"  → points to the upper, snow-covered part of the glacier
  3. "(3) ______: deep cracks, often hidden"  → points to the cracks across the ice
  4. "(4) ______ moraine: rock along the edges"  → points to the rock ridge along the edge of the glacier

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "ablation zone: ice lost mainly by (5) ______"  → points to the lower, greyer part of the glacier
  2. "(6) ______: front edge of the ice"  → points to the front edge of the ice
  3. "terminal moraine: marks the furthest (7) ______ of the ice"  → points to the curved rock ridge beyond the front edge

Small italic caption placed on or next to the drawing: "valley glacier (seen from above, flowing from left to right)".

Count check: the finished image has EXACTLY 7 labels and 7 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 7 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A map-like view from above of a valley glacier flowing from LEFT to RIGHT between mountains: an armchair-shaped hollow (cirque) at the head on the left, the accumulation zone (upper part, white snow), deep crevasses crossing the ice, ridges of rock along both edges (lateral moraines), the ablation zone (lower part, greyer ice), the snout (front edge of the ice) on the right, and a curved ridge of rock beyond it (terminal moraine). Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 7 circles in total, placed where the labels will go.
```

</details>

## 14 · Cross-section of a tree trunk  (medium)

File: `diagram_label_14.png` · Passage: "Reading the Rings" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): Cross-section of a tree trunk.

A tree trunk cut straight across, seen face-on as a disc, with concentric rings from outside to centre: rough dark outer bark, a thin inner layer (phloem), a very thin line (cambium), a wide pale band of sapwood, a darker central area of heartwood, and a small soft pith at the very centre. Clear growth rings are visible in the wood. The small caption "trunk cut across" appears under the disc.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "outer (1) ______: dead protective layer"  → points to the rough outer bark
  2. "(2) ______: carries sugars downwards"  → points to the thin layer just inside the bark
  3. "(3) ______: very thin; new cells produced here"  → points to the very thin line between that layer and the pale wood

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(4) ______: pale; carries water upwards"  → points to the wide pale band of wood
  2. "heartwood: dark; gives the tree (5) ______"  → points to the dark central wood
  3. "(6) ______: soft tissue at the centre"  → points to the small soft centre
  4. "each growth ring = (7) ______ year of growth"  → points to one single growth ring

Small italic caption placed on or next to the drawing: "trunk cut across".

Count check: the finished image has EXACTLY 7 labels and 7 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 7 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A tree trunk cut straight across, seen face-on as a disc, with concentric rings from outside to centre: rough dark outer bark, a thin inner layer (phloem), a very thin line (cambium), a wide pale band of sapwood, a darker central area of heartwood, and a small soft pith at the very centre. Clear growth rings are visible in the wood. The small caption "trunk cut across" appears under the disc. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 7 circles in total, placed where the labels will go.
```

</details>

## 15 · The human heart (front view)  (hard)

File: `diagram_label_15.png` · Passage: "The Tireless Pump" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): The human heart (front view).

A textbook front view of the human heart (as seen facing a person, so the heart's RIGHT side appears on the LEFT of the picture), with the front wall cut away to show the four chambers: right atrium (upper left of picture) with a small pacemaker area in its wall, right ventricle (lower left), left atrium (upper right), left ventricle (lower right) with a noticeably thicker wall, the septum (thick wall dividing left and right), the tricuspid valve between right atrium and right ventricle, the aorta arching over the top, and the pulmonary artery leaving the right ventricle towards the lungs.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(1) ______: carries oxygen-poor blood to the lungs"  → points to the pulmonary artery
  2. "right atrium: contains the (2) ______ (pacemaker cells)"  → points to the small pacemaker area in the wall of the right atrium
  3. "(3) ______: three flaps prevent backflow"  → points to the valve between right atrium and right ventricle
  4. "right ventricle"  → points to the right ventricle

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(4) ______: the largest artery"  → points to the aorta
  2. "(5) ______: receives blood from the lungs"  → points to the left atrium
  3. "(6) ______: thick wall between the two sides"  → points to the thick dividing wall (septum)
  4. "left ventricle: walls about (7) ______ thicker than the right"  → points to the left ventricle

Small italic caption placed on or next to the drawing: "heart (front view)".

Count check: the finished image has EXACTLY 8 labels and 8 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 8 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A textbook front view of the human heart (as seen facing a person, so the heart's RIGHT side appears on the LEFT of the picture), with the front wall cut away to show the four chambers: right atrium (upper left of picture) with a small pacemaker area in its wall, right ventricle (lower left), left atrium (upper right), left ventricle (lower right) with a noticeably thicker wall, the septum (thick wall dividing left and right), the tricuspid valve between right atrium and right ventricle, the aorta arching over the top, and the pulmonary artery leaving the right ventricle towards the lungs. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 8 circles in total, placed where the labels will go.
```

</details>

## 16 · A turbofan jet engine  (hard)

File: `diagram_label_16.png` · Passage: "How Jets Fly" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): A turbofan jet engine.

A cross-section of a turbofan jet engine drawn horizontally, FRONT (air intake) on the LEFT: a very large fan at the front, air flowing around the outside of the core (bypass air, shown with arrows), the compressor with many small blades, the combustion chamber with flames, the turbine blades behind it, a central shaft connecting the turbine to the fan and compressor, and the exhaust nozzle at the back on the right where hot gases leave.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(1) ______: can exceed 3 m in diameter"  → points to the large fan at the front
  2. "(2) ______ flows around the core"  → points to the arrows of air flowing around the core
  3. "this produces about (3) ______ of the thrust"  → points to the same bypass air flow (a second line to it)
  4. "compressor: air at up to (4) ______ original pressure"  → points to the compressor

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(5) ______: fuel burned at up to 1,500°C"  → points to the combustion chamber
  2. "turbine connected to fan and compressor by a (6) ______"  → points to the central shaft
  3. "(7) ______: gases leave the engine"  → points to the exhaust nozzle at the back

Small italic caption placed on or next to the drawing: "turbofan engine (cross-section, front on the left)".

Count check: the finished image has EXACTLY 7 labels and 7 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 7 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A cross-section of a turbofan jet engine drawn horizontally, FRONT (air intake) on the LEFT: a very large fan at the front, air flowing around the outside of the core (bypass air, shown with arrows), the compressor with many small blades, the combustion chamber with flames, the turbine blades behind it, a central shaft connecting the turbine to the fan and compressor, and the exhaust nozzle at the back on the right where hot gases leave. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 7 circles in total, placed where the labels will go.
```

</details>

## 17 · Layers of the atmosphere (not to scale)  (hard)

File: `diagram_label_17.png` · Passage: "Layers of Air" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): Layers of the atmosphere (not to scale).

A tall vertical diagram of the layers of Earth's atmosphere (not to scale): the Earth's surface curve at the bottom with clouds and mountains, then five horizontal bands from bottom to top — troposphere (with clouds and weather), stratosphere (with an ozone layer band and a passenger plane at its base), mesosphere (with a meteor streak burning up), thermosphere (with auroras and a small space station), exosphere fading into black space with stars. The top edge is marked with the small caption "outer edge of the atmosphere".

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "exosphere: gradually merges with (1) ______"  → points to the top band fading into space (exosphere)
  2. "thermosphere: (2) ______ occur; space station orbits"  → points to the fourth band with auroras (thermosphere)
  3. "mesosphere: most (3) ______ burn up; coldest layer"  → points to the third band with the meteor (mesosphere)
  4. "stratosphere: ozone absorbs (4) ______ radiation; temperature (5) ______ with height"  → points to the second band with the ozone layer (stratosphere)
  5. "troposphere: almost all (6) ______ happens; temperature (7) ______ with height"  → points to the lowest band with clouds (troposphere)

Small italic caption placed on or next to the drawing: "outer edge of the atmosphere".

Count check: the finished image has EXACTLY 5 labels and 5 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 5 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A tall vertical diagram of the layers of Earth's atmosphere (not to scale): the Earth's surface curve at the bottom with clouds and mountains, then five horizontal bands from bottom to top — troposphere (with clouds and weather), stratosphere (with an ozone layer band and a passenger plane at its base), mesosphere (with a meteor streak burning up), thermosphere (with auroras and a small space station), exosphere fading into black space with stars. The top edge is marked with the small caption "outer edge of the atmosphere". Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the right margin, 5 circles in total, placed where the labels will go.
```

</details>

## 18 · Cross-section of a sealed landfill cell  (hard)

File: `diagram_label_18.png` · Passage: "Burying the Problem" · Questions 1–8

```
Draw an educational diagram titled (do NOT write the title): Cross-section of a sealed landfill cell.

A cross-section of a completed, sealed landfill cell, layers from top to bottom: grass on topsoil, a clay cap, the waste in layers (each thin layer covered with soil) with vertical gas wells rising through it, a gravel drainage layer at the bottom with perforated pipes, a plastic liner under the gravel, a thick layer of compacted clay, and natural ground with a monitoring well going down into it at the side. The top edge is marked with the small caption "surface of the completed site".

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "topsoil planted with (1) ______"  → points to the grass and topsoil on top
  2. "clay (2) ______: keeps rainwater out"  → points to the clay cap
  3. "waste: each day's layer covered with about 15 cm of (3) ______"  → points to the waste layers with thin soil covers
  4. "waste: gas removed through vertical (4) ______"  → points to the vertical gas wells in the waste
  5. "gravel drainage layer: pipes collect (5) ______"  → points to the gravel layer with pipes
  6. "plastic liner: about (6) ______ thick"  → points to the plastic liner
  7. "compacted (7) ______: about 1 m thick"  → points to the compacted clay layer
  8. "natural ground: (8) ______ tested through monitoring wells"  → points to the natural ground and monitoring well

Small italic caption placed on or next to the drawing: "surface of the completed site".

Count check: the finished image has EXACTLY 8 labels and 8 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 8 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A cross-section of a completed, sealed landfill cell, layers from top to bottom: grass on topsoil, a clay cap, the waste in layers (each thin layer covered with soil) with vertical gas wells rising through it, a gravel drainage layer at the bottom with perforated pipes, a plastic liner under the gravel, a thick layer of compacted clay, and natural ground with a monitoring well going down into it at the side. The top edge is marked with the small caption "surface of the completed site". Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the right margin, 8 circles in total, placed where the labels will go.
```

</details>

## 19 · The human ear  (hard)

File: `diagram_label_19.png` · Passage: "The Sense of Sound" · Questions 1–7

```
Draw an educational diagram titled (do NOT write the title): The human ear.

A textbook cross-section of the human ear from outside (LEFT) to inside (RIGHT), with the three regions marked lightly as outer, middle and inner ear: the pinna (outer ear flap), the ear canal, the eardrum, the three tiny ossicle bones in the middle ear, the Eustachian tube going down from the middle ear, the three looped semicircular canals, the snail-shaped cochlea, and the auditory nerve leaving towards the brain.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(1) ______: collects sound waves"  → points to the outer ear flap (pinna)
  2. "ear canal: glands produce (2) ______"  → points to the ear canal
  3. "(3) ______: thin membrane that vibrates"  → points to the eardrum
  4. "three (4) ______: increase the force of vibrations"  → points to the three tiny bones in the middle ear

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "semicircular canals: sense of (5) ______"  → points to the three looped canals
  2. "(6) ______: snail-shaped, filled with fluid"  → points to the snail-shaped cochlea
  3. "auditory nerve"  → points to the auditory nerve
  4. "(7) ______ tube: equalises air pressure"  → points to the tube going down from the middle ear

Small italic caption placed on or next to the drawing: "ear (cross-section: outer, middle, inner)".

Count check: the finished image has EXACTLY 8 labels and 8 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 8 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A textbook cross-section of the human ear from outside (LEFT) to inside (RIGHT), with the three regions marked lightly as outer, middle and inner ear: the pinna (outer ear flap), the ear canal, the eardrum, the three tiny ossicle bones in the middle ear, the Eustachian tube going down from the middle ear, the three looped semicircular canals, the snail-shaped cochlea, and the auditory nerve leaving towards the brain. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 8 circles in total, placed where the labels will go.
```

</details>

## 20 · A modern wind turbine  (hard)

File: `diagram_label_20.png` · Passage: "Giants of the Wind" · Questions 1–8

```
Draw an educational diagram titled (do NOT write the title): A modern wind turbine.

A side view of a modern three-bladed wind turbine: a tall hollow steel tower on a concrete foundation shown below ground level, a nacelle (housing) on top with a cut-away showing the gearbox and a yaw drive at its base, a central hub at the front with three long blades and a pitch mechanism at the blade roots, and an anemometer and wind vane on top of the nacelle at the back.

Labels on the LEFT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "three blades: each can exceed (1) ______ long"  → points to one of the three long blades
  2. "(2) ______: changes the angle of the blades"  → points to the pitch mechanism at the root of a blade
  3. "central hub"  → points to the central hub
  4. "(3) ______: increases rotation speed about 100 times"  → points to the gearbox inside the nacelle

Labels on the RIGHT side, stacked top to bottom in this order. Each label has a thin leader line that ENDS WITH A SMALL DOT EXACTLY ON the part named after the arrow (the arrow text is for you only — do not write it). No two leader lines may end on the same part:
  1. "(4) ______: housing on top of the tower"  → points to the nacelle (housing)
  2. "anemometer and (5) ______: measure the wind"  → points to the anemometer and wind vane on top of the nacelle
  3. "(6) ______: rotates the nacelle to face the wind"  → points to the yaw drive at the base of the nacelle
  4. "hollow steel tower: offshore, up to (7) ______ tall"  → points to the tall tower
  5. "concrete (8) ______ below ground"  → points to the concrete foundation below ground

Small italic caption placed on or next to the drawing: "wind turbine (side view)".

Count check: the finished image has EXACTLY 9 labels and 9 leader lines — each label text appears only once, and no two lines end on the same part.

Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels.
Text rules (very important): use one clean sans-serif font, dark grey, all the same size. Write every label EXACTLY as given between the quotation marks — same words, same spelling, same brackets, numbers and blank lines "______". Do not add, translate, correct or complete any label. Do NOT write any other words anywhere on the image: no title, no legend, no answers, no watermark.
```

**Checklist:** 9 labels, each spelled exactly as listed · blanks shown only as "(n) ______" with no answer · every leader line ends with a dot on the right part (no two lines on the same part) · labels in the listed top-to-bottom order · nothing else written.

<details><summary>No-text fallback</summary>

```
Same drawing as described: A side view of a modern three-bladed wind turbine: a tall hollow steel tower on a concrete foundation shown below ground level, a nacelle (housing) on top with a cut-away showing the gearbox and a yaw drive at its base, a central hub at the front with three long blades and a pitch mechanism at the blade roots, and an anemometer and wind vane on top of the nacelle at the back. Style: clean educational textbook line illustration, like a diagram in an IELTS exam paper. Black outlines (2 px), flat soft pastel fills, white background, no shadows, no 3D, no photo realism, no decorative background. Landscape 4:3, 1600 x 1200 px. Leave a clear margin on both sides for labels. Draw NO text at all. Instead, end each leader line in an empty small circle at the left and right margins, 9 circles in total, placed where the labels will go.
```

</details>
