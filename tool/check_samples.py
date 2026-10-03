#!/usr/bin/env python3
"""Checks sample-answer files in seed/staging/writing_samples/ against GUIDE.md.

Usage: python3 tool/check_samples.py [ids or batch names ...]   (default: all)
Prints problems (errors) and figures not found in the Task 1 data (warnings:
fine only when they are correct derived values such as differences).
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BANK = json.load(open(os.path.join(ROOT, 'assets', 'content', 'writing_bank.json'), encoding='utf-8'))
ITEMS = {x['id']: x for x in BANK['task1'] + BANK['task2']}
DIR = os.path.join(ROOT, 'seed', 'staging', 'writing_samples')
RANGES = {1: {6: (160, 190), 7: (170, 205), 8: (175, 215)}, 2: {6: (255, 295), 7: (265, 315), 8: (275, 335)}}


def words(t):
    return len(re.findall(r"[A-Za-z0-9£$%'’.,-]*[A-Za-z0-9]+[A-Za-z0-9£$%'’.,-]*", t))


def nums(t):
    return {re.sub(r'[,£$%]', '', n).rstrip('.') for n in re.findall(r'[£$]?\d[\d,]*(?:\.\d+)?%?', t)}


def check(pid):
    errs, warns = [], []
    it = ITEMS.get(pid)
    path = os.path.join(DIR, pid + '.json')
    if not it:
        return [f'{pid}: unknown id'], []
    if not os.path.exists(path):
        return [f'{pid}: missing file'], []
    try:
        d = json.load(open(path, encoding='utf-8'))
    except Exception as e:
        return [f'{pid}: bad JSON ({e})'], []
    if d.get('promptId') != pid:
        errs.append(f'{pid}: promptId mismatch')
    if it['task'] == 2 and not (d.get('title') and 1 < len(d['title'].split()) <= 6):
        errs.append(f'{pid}: title missing or not 2–5 words')
    bands = sorted(s.get('band') for s in d.get('samples', []))
    if bands != [6, 7, 8]:
        errs.append(f'{pid}: bands {bands} (need 6, 7, 8)')
    data_nums = nums(it.get('dataText', '') + ' ' + it.get('statement', it.get('question', '')))
    for s in d.get('samples', []):
        t = s.get('text', '')
        w = words(t)
        lo, hi = RANGES[it['task']].get(s.get('band'), (0, 9999))
        if not lo <= w <= hi:
            errs.append(f'{pid} band {s.get("band")}: {w} words (want {lo}–{hi})')
        if t.count('\n\n') < (2 if it['task'] == 1 else 3):
            errs.append(f'{pid} band {s.get("band")}: only {t.count(chr(10) * 2) + 1} paragraphs')
        if not 12 <= len(s.get('why', '').split()) <= 40:
            errs.append(f'{pid} band {s.get("band")}: why is {len(s.get("why", "").split())} words')
        if re.search(r'^#|\*\*|^- ', t, re.M):
            errs.append(f'{pid} band {s.get("band")}: markdown in text')
        if it['task'] == 1:
            extra = sorted(n for n in nums(t) - data_nums if not re.fullmatch(r'\d', n))
            if extra:
                warns.append(f'{pid} band {s.get("band")}: figures not in data {extra}')
    texts = [s.get('text', '')[:120] for s in d.get('samples', [])]
    if len(set(texts)) < len(texts):
        errs.append(f'{pid}: samples start identically')
    return errs, warns


def main():
    args = sys.argv[1:]
    ids = []
    for a in args or [None]:
        if a is None:
            ids = list(ITEMS)
        elif a in ITEMS:
            ids.append(a)
        else:
            ids.extend(i for i in ITEMS if i.startswith('wb1_' + a.split('_', 1)[-1] + '_') or
                       i.startswith('wb2_' + a.split('_', 1)[-1] + '_') or i.startswith(a))
    E, W = [], []
    for pid in ids:
        e, w = check(pid)
        E += e
        W += w
    for x in E:
        print('ERROR', x)
    for x in W:
        print('WARN ', x)
    print(f'{len(ids)} checked · {len(E)} errors · {len(W)} warnings')


if __name__ == '__main__':
    main()
