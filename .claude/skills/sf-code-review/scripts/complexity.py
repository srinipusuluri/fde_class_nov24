#!/usr/bin/env python3
"""Approximate per-method cyclomatic complexity and size for Apex (.cls/.trigger) and LWC/Aura JS.

Usage: complexity.py <file-or-dir> [...]   -> JSON on stdout
Heuristic (regex based, not a parser): CC = 1 + count of decision points in a method body.
"""
import json, re, sys
from pathlib import Path

DECISION = re.compile(r'\b(if|for|while|case|catch|when)\b|&&|\|\||\?(?![.?])|\?\?')
METHOD = re.compile(
    r'^[ \t]*(?:@\w+(?:\([^)]*\))?[ \t]*\n?[ \t]*)*'
    r'(?:(?:public|private|global|protected|static|override|virtual|abstract|testmethod|async)[ \t]+)*'
    r'(?:[\w<>\[\],.]+[ \t]+)?(\w+)[ \t]*\(([^)]*)\)[ \t]*\{', re.M)
SKIP = {'if', 'for', 'while', 'switch', 'catch', 'else', 'when', 'try', 'return', 'new'}

def strip(src):
    # Strings first (a URL like '/a/*' must not open a block comment), then comments.
    src = re.sub(r"'(?:\\.|[^'\\\n])*'|\"(?:\\.|[^\"\\\n])*\"", "''", src)
    src = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), src, flags=re.S)
    return re.sub(r'//[^\n]*', '', src)

def analyze(path):
    raw = Path(path).read_text(errors='ignore')
    src = strip(raw)
    out = []
    for m in METHOD.finditer(src):
        name = m.group(1)
        if name in SKIP:
            continue
        i, depth = m.end() - 1, 0
        for j in range(i, len(src)):
            if src[j] == '{': depth += 1
            elif src[j] == '}':
                depth -= 1
                if depth == 0: break
        body = src[i:j + 1]
        line = src[:m.start()].count('\n') + 1
        out.append({'method': name, 'line': line, 'lines': body.count('\n') + 1,
                    'params': len([p for p in m.group(2).split(',') if p.strip()]),
                    'complexity': 1 + len(DECISION.findall(body)),
                    'max_nesting': max_nesting(body)})
    return {'file': str(path), 'total_lines': raw.count('\n') + 1, 'methods': out}

def max_nesting(body):
    d = m = 0
    for c in body:
        if c == '{': d += 1; m = max(m, d)
        elif c == '}': d -= 1
    return max(m - 1, 0)

def files(args):
    for a in args:
        p = Path(a)
        yield from ([p] if p.is_file() else [f for f in p.rglob('*') if f.suffix in {'.cls', '.trigger', '.js'} and 'node_modules' not in f.parts and '__tests__' not in f.parts])

if __name__ == '__main__':
    print(json.dumps([analyze(f) for f in files(sys.argv[1:] or ['.'])], indent=2))
