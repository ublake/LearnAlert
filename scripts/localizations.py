#!/usr/bin/env python3
"""Sync compiler-extracted UI strings and validate shipping localization coverage.

Build with SWIFT_EMIT_LOC_STRINGS=YES before --extract. Translation edits belong
in Localizable.xcstrings; this tool preserves existing translations and old keys.
"""
import argparse, collections, json, pathlib, re, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'LearnAlert/Localizable.xcstrings'
LANGUAGES = ('es', 'pt-BR', 'fr', 'de', 'ja', 'ko')
TOKEN = re.compile(r'%(?:(\d+)\$)?(?:[-+#0 ]*\d*(?:\.\d+)?)(lld|llu|ld|lu|d|u|f|g|@|s)|%%')

def tokens(text):
    found = []
    for m in TOKEN.finditer(text):
        if m.group(0) != '%%': found.append((m.group(1), m.group(2)))
    return found

def units(node):
    if isinstance(node, dict):
        if 'stringUnit' in node: yield node['stringUnit']['value']
        for key, value in node.items():
            if key != 'stringUnit': yield from units(value)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--extract', type=pathlib.Path)
    parser.add_argument('--keys', type=pathlib.Path)
    args = parser.parse_args()
    data = json.loads(CATALOG.read_text())
    if args.extract:
        sources = collections.defaultdict(set)
        for file in args.extract.rglob('*.stringsdata'):
            try: item = json.loads(file.read_text())
            except (ValueError, OSError): continue
            source = pathlib.Path(item.get('source', ''))
            if not source.is_relative_to(ROOT) or not source.exists(): continue
            if not (source.is_relative_to(ROOT/'LearnAlert') or source.is_relative_to(ROOT/'LearnAlertExtension') or source.is_relative_to(ROOT/'Packages/AnkiArchive')): continue
            for entry in item.get('tables', {}).get('Localizable', []):
                if entry['key']: sources[entry['key']].add(str(source.relative_to(ROOT)))
        for key, paths in sources.items():
            entry = data['strings'].setdefault(key, {})
            entry['comment'] = 'Interface copy. ' + ', '.join(sorted(paths))
            # Branding and format-only strings intentionally retain their value.
            rest = TOKEN.sub('', key)
            if key in ('LearnAlert', 'Anki', 'iOS', 'Swift', 'GPT-4o') or not re.search(r'[A-Za-z\u00c0-\u024f\u3040-\u30ff\uac00-\ud7af]', rest):
                entry['shouldTranslate'] = False
        data['strings'] = dict(sorted(data['strings'].items()))
        CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
    keys = [k for k,v in data['strings'].items() if v.get('shouldTranslate') is not False]
    if args.keys:
        args.keys.write_text(json.dumps(keys,ensure_ascii=False,indent=2)+'\n')
    errors = []
    for language in LANGUAGES:
        missing = []
        for key in keys:
            entry = data['strings'][key].get('localizations', {}).get(language)
            if not entry: missing.append(key); continue
            for value in units(entry):
                if not value.strip(): errors.append(f'{language}: empty {key!r}')
                # Positional forms can reorder arguments; each index must keep its type.
                expected = {int(p or i):t for i,(p,t) in enumerate(tokens(key),1)}
                actual = {int(p or i):t for i,(p,t) in enumerate(tokens(value),1)}
                if 'substitutions' not in entry and expected != actual:
                    errors.append(f'{language}: format mismatch {key!r} -> {value!r}')
        print(f'{language}: {len(keys)-len(missing)}/{len(keys)} interface strings translated')
        if missing: errors.append(f'{language}: {len(missing)} missing translations')
    for error in errors[:30]: print(error, file=sys.stderr)
    return bool(errors)
if __name__ == '__main__': sys.exit(main())
