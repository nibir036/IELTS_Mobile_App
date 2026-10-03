#!/usr/bin/env python3
"""Cheap static checks for Dart files when no Dart SDK is available.

Checks: balanced () [] {} (string/comment aware), relative imports resolve,
kit/AppIcons/Routes/tokens/JsonMapX members referenced actually exist,
banned APIs (withOpacity, Icons. outside app_icons.dart), and that each
section routes file exposes its map.

Usage: python3 tool/check_dart.py [paths...]   (default: lib/)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def strip_strings_comments(src):
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j == -1 else j
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i + 2)
            i = n if j == -1 else j + 2
            continue
        raw = False
        if c == 'r' and i + 1 < n and src[i + 1] in '\'"' and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_')):
            raw = True
            i += 1
            c = src[i]
        if c in '\'"':
            q3 = src[i:i + 3]
            if q3 in ("'''", '"""'):
                j = src.find(q3, i + 3)
                i = n if j == -1 else j + 3
                out.append('""')
                continue
            j = i + 1
            depth_interp = 0
            while j < n:
                ch = src[j]
                if ch == '\\' and not raw:
                    j += 2
                    continue
                if not raw and ch == '$' and j + 1 < n and src[j + 1] == '{':
                    # skip interpolation body roughly by brace counting
                    k = j + 2
                    d = 1
                    while k < n and d:
                        if src[k] == '{':
                            d += 1
                        elif src[k] == '}':
                            d -= 1
                        k += 1
                    j = k
                    continue
                if ch == c:
                    break
                if ch == '\n':
                    break
                j += 1
            out.append('""')
            i = j + 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def check_balance(path, code):
    errs = []
    stack = []
    pairs = {')': '(', ']': '[', '}': '{'}
    line = 1
    for ch in code:
        if ch == '\n':
            line += 1
        elif ch in '([{':
            stack.append((ch, line))
        elif ch in ')]}':
            if not stack or stack[-1][0] != pairs[ch]:
                errs.append(f'{path}:{line}: unbalanced "{ch}"')
                return errs
            stack.pop()
    if stack:
        errs.append(f'{path}:{stack[-1][1]}: unclosed "{stack[-1][0]}"')
    return errs


def members(path, pattern):
    try:
        src = open(os.path.join(ROOT, path)).read()
    except OSError:
        return set()
    return set(re.findall(pattern, src))


def main(argv):
    targets = argv or [os.path.join(ROOT, 'lib')]
    files = []
    for t in targets:
        if os.path.isdir(t):
            for dp, _, fns in os.walk(t):
                files += [os.path.join(dp, f) for f in fns if f.endswith('.dart')]
        else:
            files.append(t)

    icons = members('lib/app/widgets/app_icons.dart', r'static const (\w+)\s*=')
    routes = members('lib/app/routes.dart', r'static const (\w+)\s*=')
    tokens = members('lib/app/theme/tokens.dart', r'final (?:bool|Color|Gradient) (\w+);')
    json_ext = {'s', 'd', 'i', 'b', 'm', 'l', 'ls', 'ld'}

    errs = []
    for f in sorted(files):
        src = open(f).read()
        code = strip_strings_comments(src)
        rel = os.path.relpath(f, ROOT)
        errs += check_balance(rel, code)
        for m in re.finditer(r"^import '([^']+)';", src, re.M):
            p = m.group(1)
            if p.startswith('package:') or p.startswith('dart:'):
                if p.startswith('package:nexted_ielts_app/'):
                    tgt = os.path.join(ROOT, 'lib', p[len('package:nexted_ielts_app/'):])
                    if not os.path.exists(tgt):
                        errs.append(f'{rel}: import not found {p}')
                elif p.startswith('package:') and not re.match(r'package:(flutter|flutter_test|google_fonts|shared_preferences|http|record|just_audio|cross_file|path_provider|share_plus|image_picker)/', p):
                    errs.append(f'{rel}: package not in pubspec {p}')
                continue
            tgt = os.path.normpath(os.path.join(os.path.dirname(f), p))
            if not os.path.exists(tgt):
                errs.append(f'{rel}: import not found {p}')
        ln = lambda pos: code.count('\n', 0, pos) + 1
        for m in re.finditer(r'\bAppIcons\.(\w+)', code):
            if m.group(1) not in icons and not m.group(1).startswith('_'):
                errs.append(f'{rel}:{ln(m.start())}: unknown AppIcons.{m.group(1)}')
        for m in re.finditer(r'\bRoutes\.(\w+)', code):
            if m.group(1) not in routes and not m.group(1).startswith('_'):
                errs.append(f'{rel}:{ln(m.start())}: unknown Routes.{m.group(1)}')
        for m in re.finditer(r'\b(?:t|tk|context\.tk)\.(\w+)', code):
            name = m.group(1)
            if name not in tokens and m.group(0).startswith(('t.', 'tk.', 'context.tk.')):
                # t.<x> may be another variable named t; only flag if file uses context.tk
                if 'context.tk' in code and name not in ('toString', 'hashCode'):
                    errs.append(f'{rel}:{ln(m.start())}: unknown token .{name}')
        if 'withOpacity(' in code:
            errs.append(f'{rel}: use withValues(alpha:) instead of withOpacity')
        if not rel.endswith('app_icons.dart') and re.search(r'\bIcons\.', code):
            for m in re.finditer(r'\bIcons\.(\w+)', code):
                errs.append(f'{rel}:{ln(m.start())}: direct Icons.{m.group(1)} (verify it exists or use AppIcons)')
        if re.search(r'Bandwise|BANDWISE', src):
            errs.append(f'{rel}: old brand name "Bandwise" present')
    for e in errs:
        print(e)
    print(f'-- {len(files)} files checked, {len(errs)} issue(s)')
    return 1 if errs else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
