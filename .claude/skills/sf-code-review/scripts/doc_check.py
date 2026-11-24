#!/usr/bin/env python3
"""Comment-coverage and comment-only-change checks for Apex (.cls/.trigger) and JS.

  doc_check.py coverage <file-or-dir> ...   -> JSON: classes/methods missing a doc comment
  doc_check.py verify <original> <edited>   -> exit 0 if code is identical ignoring comments
                                               and whitespace, exit 1 (with a diff hint) if not
"""
import json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from complexity import METHOD, SKIP, strip, files  # reuse the same parsing

TYPE_DECL = re.compile(r'^[ \t]*(?:@\w+(?:\([^)]*\))?[ \t]*\n?[ \t]*)*(?:(?:public|private|global|with sharing|without sharing|inherit sharing|virtual|abstract|static)[ \t]+)*(class|interface|enum)[ \t]+(\w+)', re.M)

def has_doc_above(raw_lines, line_no):
    """True if the nearest non-blank line above `line_no` (1-based) closes a /** */ block."""
    i = line_no - 2
    while i >= 0 and not raw_lines[i].strip():
        i -= 1
    if i < 0 or not raw_lines[i].rstrip().endswith('*/'):
        return False
    j = i
    while j >= 0 and '/*' not in raw_lines[j]:
        j -= 1
    return j >= 0 and raw_lines[j].lstrip().startswith('/**')

def coverage(path):
    raw = Path(path).read_text(errors='ignore')
    lines = raw.split('\n')
    src = strip(raw)
    missing, total = [], 0
    for m in TYPE_DECL.finditer(src):
        ln = src[:m.start()].count('\n') + 1
        total += 1
        # only top-level and inner types; tests are skipped below
        if not has_doc_above(lines, ln):
            missing.append({'kind': m.group(1), 'name': m.group(2), 'line': ln})
    for m in METHOD.finditer(src):
        if m.group(1) in SKIP:
            continue
        ln = src[:m.start()].count('\n') + 1
        total += 1
        if not has_doc_above(lines, ln):
            missing.append({'kind': 'method', 'name': m.group(1), 'line': ln})
    return {'file': str(path), 'documentable': total, 'missing': missing,
            'coverage_pct': round(100 * (total - len(missing)) / total) if total else 100}

def normalize(path):
    return re.sub(r'\s+', '', strip(Path(path).read_text(errors='ignore')))

if __name__ == '__main__':
    if len(sys.argv) >= 4 and sys.argv[1] == 'verify':
        a, b = normalize(sys.argv[2]), normalize(sys.argv[3])
        if a == b:
            print('OK: only comments/whitespace changed'); sys.exit(0)
        k = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
        print(f'CODE CHANGED near: ...{a[max(0,k-40):k+40]}...  vs  ...{b[max(0,k-40):k+40]}...')
        sys.exit(1)
    if len(sys.argv) >= 3 and sys.argv[1] == 'coverage':
        print(json.dumps([coverage(f) for f in files(sys.argv[2:]) if '/__tests__/' not in str(f)], indent=2)); sys.exit(0)
    print(__doc__); sys.exit(2)
