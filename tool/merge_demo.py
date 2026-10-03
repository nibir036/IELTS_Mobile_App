#!/usr/bin/env python3
"""Merge assets/demo/parts/*.json into assets/demo/demo_data.json.

Content parts: access, home, writing, speaking, reading, listening, mock,
resources (+ user, kept for reference). Demo-account seed: accounts.json plus
seed_<section>.json files ({attempts, notifications, tasks, kv}) which are
appended to the first (demo) account's data.
"""
import glob
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, 'assets', 'demo', 'parts')

out = {}
for k in ['user', 'access', 'home', 'writing', 'speaking', 'reading', 'listening', 'mock', 'resources']:
    f = os.path.join(P, k + '.json')
    if os.path.exists(f):
        out[k] = json.load(open(f))

accounts = json.load(open(os.path.join(P, 'accounts.json')))
data = accounts[0].setdefault('data', {})
for key in ('attempts', 'notifications', 'tasks'):
    data.setdefault(key, [])
data.setdefault('kv', {})
for f in sorted(glob.glob(os.path.join(P, 'seed_*.json'))):
    seed = json.load(open(f))
    for key in ('attempts', 'notifications', 'tasks'):
        data[key] += seed.get(key, [])
    data['kv'].update(seed.get('kv', {}))
out['accounts'] = accounts

# Content bank: assets/demo/content/*.json deep-merged under "content"
# (dicts merge, lists concatenate) — see CONTENT_SCHEMA.md.
def deep_merge(a, b):
    for k, v in b.items():
        if k in a and isinstance(a[k], dict) and isinstance(v, dict):
            deep_merge(a[k], v)
        elif k in a and isinstance(a[k], list) and isinstance(v, list):
            a[k] = a[k] + v
        else:
            a[k] = v
    return a

content = {}
for f in sorted(glob.glob(os.path.join(ROOT, 'assets', 'demo', 'content', '*.json'))):
    deep_merge(content, json.load(open(f)))
out['content'] = content

dst = os.path.join(ROOT, 'assets', 'demo', 'demo_data.json')
json.dump(out, open(dst, 'w'), indent=2, ensure_ascii=False)
print('wrote', dst, os.path.getsize(dst), 'bytes;',
      len(data['attempts']), 'attempts,', len(data['notifications']), 'notifications,',
      len(data['tasks']), 'tasks,', len(data['kv']), 'kv keys;',
      {k: {kk: len(vv) for kk, vv in v.items() if isinstance(vv, list)} for k, v in content.items()})
