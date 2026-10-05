"""Align a listening script (transcript lines) with the recording's subtitle file (.srt).

align(lines, srt_text) → (starts, report): a start time (s) for every line, plus a report of
recording stretches that match no script line (extra / repeated audio) and lines never heard."""
import difflib
import re

NUM = {'zero': '0', 'oh': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6',
       'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10'}


def norm_words(s):
    s = s.lower().replace('’', "'").replace('£', ' ').replace('$', ' ')
    out = []
    for w in re.findall(r"[a-z0-9']+", s):
        w = w.strip("'")
        if w:
            out.append(NUM.get(w, w))
    return out


def srt_words(text):
    """[(word, time)] with times spread evenly across each cue."""
    out = []
    for h, m, s, ms, h2, m2, s2, ms2, body in re.findall(
            r'(\d+):(\d+):(\d+)[,.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,.](\d+)\s*\n(.*?)(?:\n\s*\n|\Z)', text, re.S):
        a = int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000
        b = int(h2) * 3600 + int(m2) * 60 + int(s2) + int(ms2) / 1000
        ws = norm_words(body)
        for i, w in enumerate(ws):
            out.append((w, a + (b - a) * i / max(1, len(ws))))
    return out


def align(lines, srt_text, anchors=None):
    sw = srt_words(srt_text)
    tw, owner = [], []
    for li, line in enumerate(lines):
        for w in norm_words(line):
            tw.append(w)
            owner.append(li)
    sm = difflib.SequenceMatcher(None, tw, [w for w, _ in sw], autojunk=False)
    t2s = {}
    srt_used = [False] * len(sw)
    for a, b, n in sm.get_matching_blocks():
        if n < 2:  # single-word coincidences are noise
            continue
        for k in range(n):
            t2s[a + k] = b + k
            srt_used[b + k] = True
    starts, matched = [], []
    first_tok = {}
    for i, li in enumerate(owner):
        first_tok.setdefault(li, i)
    for li in range(len(lines)):
        i0 = first_tok.get(li)
        t = None
        hits = 0
        if i0 is not None:
            j = i0
            while j < len(owner) and owner[j] == li:
                if j in t2s:
                    hits += 1
                    if t is None:
                        t = sw[t2s[j]][1] - 0.33 * (j - i0)  # words before the first heard one
                j += 1
            total = j - i0
        else:
            total = 0
        starts.append(t)
        matched.append((hits, total))
    for i, t in (anchors or {}).items():
        starts[i] = float(t)
        matched[i] = (matched[i][1], matched[i][1])
    # fill gaps by interpolating on word counts between the nearest known lines
    pos, acc = [], 0
    for line in lines:
        pos.append(acc)
        acc += max(1, len(norm_words(line)))
    known = [i for i, t in enumerate(starts) if t is not None]
    for i in range(len(starts)):
        if starts[i] is None:
            prev = max([k for k in known if k < i], default=None)
            nxt = min([k for k in known if k > i], default=None)
            if prev is not None and nxt is not None:
                starts[i] = starts[prev] + (starts[nxt] - starts[prev]) * (pos[i] - pos[prev]) / max(1, pos[nxt] - pos[prev])
            elif prev is not None:
                starts[i] = starts[prev] + 0.4 * (pos[i] - pos[prev])
            else:
                starts[i] = 0.0
    for i in range(1, len(starts)):
        if starts[i] < starts[i - 1]:
            starts[i] = starts[i - 1] + 0.1
    # stretches of recording that match nothing (≥ 12 words in a row)
    extra, run = [], []
    for k, used in enumerate(srt_used + [True]):
        if not used:
            run.append(k)
        else:
            if len(run) >= 12:
                extra.append((round(sw[run[0]][1], 1), round(sw[run[-1]][1], 1),
                              ' '.join(sw[x][0] for x in run[:14])))
            run = []
    unheard = [(i, lines[i][:70]) for i, (h, tot) in enumerate(matched) if tot >= 6 and h / tot < 0.3]
    heard = [tot == 0 or h / tot >= 0.3 for h, tot in matched]
    return [round(max(0.0, s), 2) for s in starts], {'extra': extra, 'unheard': unheard,
                                                      'coverage': round(sum(srt_used) / max(1, len(sw)), 3), 'heard': heard}
