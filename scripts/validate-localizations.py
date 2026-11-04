#!/usr/bin/env python3
"""Check bundled locale coverage and printf argument safety before building."""
import argparse
import collections
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORMAT = re.compile(r'%(?:(\d+)\$)?[-+#0 ]*(?:\d+)?(?:\.\d+)?(lld|llu|ld|lu|d|u|f|g|@|%)')


def arguments(value, strict=False):
    """Compare argument positions and types, allowing translated word order."""
    if strict and '%' in FORMAT.sub('', value):
        raise ValueError('unescaped or unsupported percent format')
    result = collections.Counter()
    position = 1
    positioning = set()
    for match in FORMAT.finditer(value):
        explicit, kind = match.groups()
        if kind == '%':
            continue
        positioning.add(bool(explicit))
        index = int(explicit) if explicit else position
        result[index, kind] += 1
        if not explicit:
            position += 1
    if len(positioning) > 1:
        raise ValueError('mixed positional and sequential format arguments')
    return result


def units(node):
    if 'stringUnit' in node:
        yield node['stringUnit']
    for choices in node.get('variations', {}).values():
        for child in choices.values():
            yield from units(child)


def main(require_reviewed=False):
    manifest = json.loads((ROOT / 'Configuration/SupportedLocalizations.json').read_text())
    locales = {item['bundle'] for item in manifest['locales']}
    errors = []
    states = collections.Counter()
    for path in sorted((ROOT / 'Alertivity/Resources').glob('*.xcstrings')):
        catalog = json.loads(path.read_text())
        source = catalog['sourceLanguage']
        for key, entry in catalog['strings'].items():
            if entry.get('shouldTranslate') is False:
                continue
            localized = entry.get('localizations', {})
            original = localized.get(source, {}).get('stringUnit', {}).get('value', key)
            for locale in sorted(locales):
                translation = localized.get(locale)
                if translation is None:
                    if locale == source and not re.match(r'^[a-zA-Z]+\.', key):
                        continue  # Literal English keys are valid source fallbacks.
                    errors.append(f'{path.name}: {key!r}: missing {locale}')
                    continue
                values = list(units(translation))
                if not values:
                    errors.append(f'{path.name}: {key!r}: no string units for {locale}')
                for unit in values:
                    states[unit.get('state', 'new')] += 1
                    if unit.get('state') not in {'translated', 'needs_review'}:
                        errors.append(f'{path.name}: {key!r}: unfinished state for {locale}')
                    value = unit['value']
                    if key == 'CFBundleName' and value != 'Alertivity':
                        errors.append(f'{path.name}: app name changed for {locale}')
                    if not value.strip() and original.strip():
                        errors.append(f'{path.name}: {key!r}: empty {locale}')
                    try:
                        original_arguments = arguments(original)
                        if arguments(value, strict=bool(original_arguments)) != original_arguments:
                            errors.append(f'{path.name}: {key!r}: arguments differ for {locale}')
                    except ValueError as error:
                        errors.append(f'{path.name}: {key!r}: {locale}: {error}')
                    if re.search(r'&(?:amp|lt|gt|quot|apos);', value):
                        errors.append(f'{path.name}: {key!r}: XML entity in {locale}')
                    if re.search(r'\\u[0-9a-fA-F]{4}', value):
                        errors.append(f'{path.name}: {key!r}: literal Unicode escape in {locale}')
        print(json.dumps({'event': 'catalog_checked', 'catalog': path.name,
                          'keys': len(catalog['strings']), 'locales': len(locales)}))
    project = (ROOT / 'Alertivity.xcodeproj/project.pbxproj').read_text()
    region_section = re.search(r'knownRegions = \((.*?)\);', project, re.S).group(1)
    regions = set(re.findall(r'"?([\w-]+)"?\s*,', region_section))
    if locales - regions:
        errors.append(f'Project knownRegions missing: {sorted(locales - regions)}')
    if require_reviewed and states['needs_review']:
        errors.append(f"Language review pending for {states['needs_review']} string units")
    for error in errors:
        print(json.dumps({'level': 'error', 'event': 'localization_invalid', 'detail': error}), file=sys.stderr)
    print(json.dumps({'event': 'localization_validation_completed', 'errors': len(errors), 'states': states}))
    return bool(errors)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-reviewed', action='store_true', help='Fail until every translation has completed review')
    sys.exit(main(parser.parse_args().require_reviewed))
