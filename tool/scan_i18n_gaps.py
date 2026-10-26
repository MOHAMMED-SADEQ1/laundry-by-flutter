"""Scanner for Dart string literals containing Arabic — dev tool, not shipped.

Handles single, double, and triple-quoted strings, skips comments, and
normalizes whitespace so multi-line literals match single-line dictionary keys.
"""
import re, os, sys, json

ARABIC = re.compile(r'[\u0600-\u06FF]')
WS = re.compile(r'\s+')

ESCAPES = {'n': '\n', 'r': '\r', 't': '\t', "'": "'", '"': '"',
           '\\': '\\', '$': '$', 'b': '\b', 'f': '\f', 'v': '\v', '0': '\0'}


def decode(raw: str) -> str:
    """Turn a Dart escape sequence into the character it represents.

    The dictionary key must equal the *runtime* value, not the source text, so
    `'\\n'` in the source has to become a real newline before comparison.
    """
    out = []
    i = 0
    while i < len(raw):
        if raw[i] == '\\' and i + 1 < len(raw):
            out.append(ESCAPES.get(raw[i + 1], raw[i + 1]))
            i += 2
            continue
        out.append(raw[i])
        i += 1
    return ''.join(out)


def normalize(text: str) -> str:
    return WS.sub(' ', text).strip()


def scan_source(src: str):
    """Yield (literal_value, offset) for every string literal."""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        # comments
        if c == '/' and i + 1 < n:
            if src[i + 1] == '/':
                j = src.find('\n', i)
                i = n if j < 0 else j + 1
                continue
            if src[i + 1] == '*':
                j = src.find('*/', i + 2)
                i = n if j < 0 else j + 2
                continue
        if c in "'\"":
            triple = src[i:i + 3] == c * 3
            quote = c * 3 if triple else c
            j = i + len(quote)
            buf = []
            while j < n:
                if src[j] == '\\':
                    buf.append(src[j:j + 2])
                    j += 2
                    continue
                if src[j:j + len(quote)] == quote:
                    j += len(quote)
                    break
                buf.append(src[j])
                j += 1
            yield decode(''.join(buf)), i
            i = j
            continue
        i += 1


def dictionary_keys(path: str):
    src = open(path, encoding='utf-8').read()
    keys = set()
    for value, _ in scan_source(src):
        keys.add(normalize(value))
    return keys


def main():
    root = 'lib'
    dict_path = 'lib/services/i18n/translations_en.dart'
    known = dictionary_keys(dict_path)
    # every literal in the dictionary is either a key or a value; only keys matter,
    # but values are English so they contain no Arabic and cannot collide.
    rows = []
    for dirpath, _, files in os.walk(root):
        if 'i18n' in dirpath.replace('\\', '/'):
            continue
        for name in sorted(files):
            if not name.endswith('.dart'):
                continue
            path = os.path.join(dirpath, name)
            src = open(path, encoding='utf-8').read()
            for value, offset in scan_source(src):
                if not ARABIC.search(value):
                    continue
                key = normalize(value)
                if not key or key in known:
                    continue
                line = src[:offset].count('\n') + 1
                before = src[max(0, offset - 4):offset]
                wrapped = 'tr(' in before or 'trf(' in before
                rows.append({
                    'file': path.replace('\\', '/'),
                    'line': line,
                    'key': key,
                    'wrapped': wrapped,
                })
    uniq = {}
    for r in rows:
        uniq.setdefault(r['key'], []).append(r)
    print(json.dumps({
        'occurrences': len(rows),
        'unique': len(uniq),
        'wrapped_occ': sum(1 for r in rows if r['wrapped']),
        'unwrapped_occ': sum(1 for r in rows if not r['wrapped']),
        'unique_unwrapped': sum(1 for k, v in uniq.items() if not any(x['wrapped'] for x in v)),
    }, ensure_ascii=False, indent=2))
    if len(sys.argv) > 1 and sys.argv[1] == 'dump':
        for key in sorted(uniq):
            print(key)


if __name__ == '__main__':
    main()
