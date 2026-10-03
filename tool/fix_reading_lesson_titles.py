"""Repair set-lesson titles that swallowed the first body sentence (PDF quirk) in already-imported data.

usage: python3 tool/fix_reading_lesson_titles.py
Applies import_reading_bank.fix_set_lesson to seed/data/27_reading_bank_passages.json and the English
translation sources (seed/staging/l10n/reading/src/passages_*.json), then rebuild the app asset with
`python3 tool/build_reading_bank_asset.py`. A fresh import (tool/import_reading_bank.py) does this itself.
"""
import importlib.util
import json
import sys
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# import the importer without needing pdfplumber (only the pure-text helper is used)
sys.modules.setdefault('pdfplumber', types.ModuleType('pdfplumber'))
spec = importlib.util.spec_from_file_location('import_reading_bank', ROOT / 'tool' / 'import_reading_bank.py')
irb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(irb)


def fix_file(path, lessons):
    data = json.loads(path.read_text(encoding='utf-8'))
    fixed = [x['id'] for x in lessons(data) if irb.fix_set_lesson(x['lesson'])]
    if fixed:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2 if 'seed/data' in str(path) else 1),
                        encoding='utf-8')
    print(f'{path.relative_to(ROOT)}: {fixed or "nothing to fix"}')


def main():
    fix_file(ROOT / 'seed' / 'data' / '27_reading_bank_passages.json', lambda d: d['items'])
    for f in sorted((ROOT / 'seed' / 'staging' / 'l10n' / 'reading' / 'src').glob('passages_*.json')):
        fix_file(f, lambda d: d)


if __name__ == '__main__':
    main()
