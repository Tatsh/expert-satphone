"""Generate per-method reconstruction-status tables covering every authored Objective-C method.

Run from the recon-tools checkout so its modules are importable::

    uv run python /path/to/jubeat-src/tools/status_tables_gen.py \\
        /path/to/Jubeat.app/Jubeat /path/to/jubeat-src [--xrefs-host HOST:PORT]

Writes STATUS_00.md, STATUS_01.md, ... into the tree root, at most 1000 method rows per file,
plus a STATUS.md index. Each row is a method in ``-[ClassName selector]`` form, a status tick, its
cross-reference count, and its byte length in the binary.

Authored methods only: the same accounting as tools/progress.py. Compiler-emitted ``.cxx_destruct``
and synthesised property accessors (those a plain ``@property`` satisfies without a hand-written
body) are excluded; hand-written accessors -- an accessor whose body exceeds the trivial size -- are
kept, because those are real work.

Cross-reference counts come from the Ghidra HTTP bridge's ``get_xrefs_to`` endpoint; every request
is scoped to the Jubeat program. When the bridge is unreachable the count column is left blank.
"""

import itertools
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path

from recon_tools.arm64 import INSTRUCTION_SIZE, body_length
from recon_tools.macho import IMAGE_BASE, MachOBinary
from recon_tools.objc import TRIVIAL_INSTRUCTIONS, source_bodies

# Never written by hand, so never part of the authored surface. ARC emits .cxx_destruct to release
# a class's strong ivars and it has no source form at all.
_COMPILER_GENERATED = ('.cxx_destruct',)

_ROWS_PER_FILE = 1000
_DEFAULT_HOST = 'localhost:8089'
_PROGRAM = 'Jubeat'


def _is_accessor(selector, properties):
    if selector in properties:
        return True
    if selector.startswith('set') and selector.endswith(':') and len(selector) > 4:
        return selector[3].lower() + selector[4:-1] in properties
    return False


def _hand_written_accessors(binary, methods, properties, ends):
    out = set()
    for (cls, kind, sel), address in methods.items():
        if not _is_accessor(sel, properties.get(cls, {})):
            continue
        end = ends.get(address)
        if end is None:
            continue
        instructions = (end - address) // INSTRUCTION_SIZE
        if body_length(binary, address, instructions) > TRIVIAL_INSTRUCTIONS:
            out.add((cls, kind, sel))
    return out


def _xref_count(host, address):
    """Return the number of cross-references to an address, or None when the bridge is unreachable."""
    query = urllib.parse.urlencode({'address': f'0x{address:x}', 'program': _PROGRAM})
    url = f'http://{host}/get_xrefs_to?{query}'
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            body = response.read().decode('utf-8', 'replace').strip()
    except (urllib.error.URLError, OSError):
        return None
    if not body or body.lower().startswith('no references'):
        return 0
    return sum(1 for line in body.splitlines() if line.strip())


def _method_label(cls, kind, sel):
    return f'`{kind}[{cls} {sel}]`'


def main():
    args = list(sys.argv[1:])
    host = _DEFAULT_HOST
    if '--xrefs-host' in args:
        index = args.index('--xrefs-host')
        host = args[index + 1]
        del args[index:index + 2]
    binary_path, tree_path = Path(args[0]), Path(args[1])

    binary = MachOBinary(binary_path)
    methods = binary.method_map()
    properties = binary.property_map()
    written = set(source_bodies(tree_path))

    addresses = sorted(set(methods.values()))
    ends = dict(itertools.pairwise(addresses))
    hand_written = _hand_written_accessors(binary, methods, properties, ends)

    authored = []
    for (cls, kind, sel), address in methods.items():
        if sel in _COMPILER_GENERATED:
            continue
        if _is_accessor(sel, properties.get(cls, {})) and (cls, kind, sel) not in hand_written:
            continue
        authored.append((cls, kind, sel, address))

    # Group by class, classes alphabetical, methods by address within a class.
    by_class = defaultdict(list)
    for cls, kind, sel, address in authored:
        by_class[cls].append((kind, sel, address))
    ordered = []
    for cls in sorted(by_class, key=str.lower):
        for kind, sel, address in sorted(by_class[cls], key=lambda row: row[2]):
            ordered.append((cls, kind, sel, address))

    total = len(ordered)
    done = sum(1 for cls, kind, sel, _ in ordered if (cls, kind, sel) in written)

    # Pack whole classes into files of at most _ROWS_PER_FILE rows, so no class is split across two
    # files (a single class larger than the cap still gets its own oversized file).
    class_order = sorted(by_class, key=str.lower)
    chunks = []
    current = []
    for cls in class_order:
        rows = [(cls, kind, sel, address)
                for kind, sel, address in sorted(by_class[cls], key=lambda row: row[2])]
        if current and len(current) + len(rows) > _ROWS_PER_FILE:
            chunks.append(current)
            current = []
        current.extend(rows)
    if current:
        chunks.append(current)
    file_count = len(chunks)

    xref_reachable = _xref_count(host, IMAGE_BASE + 0x480c) is not None

    generated_files = []
    for file_index, chunk in enumerate(chunks):
        first_class = chunk[0][0]
        last_class = chunk[-1][0]
        name = f'STATUS_{file_index:02d}.md'
        generated_files.append((name, first_class, last_class, len(chunk)))
        lines = [
            f'# Reconstruction status {file_index + 1} of {file_count}',
            '',
            f'Methods for classes `{first_class}` through `{last_class}`.',
            '',
            'Generated by `tools/status_tables_gen.py`; do not edit by hand.',
            '',
            '| Method | Status | # xrefs | Length |',
            '| ------ | ------ | ------- | ------ |',
        ]
        for cls, kind, sel, address in chunk:
            status = '✅' if (cls, kind, sel) in written else '❌'
            end = ends.get(address)
            length = f'{end - address}' if end is not None else ''
            xrefs = ''
            if xref_reachable:
                count = _xref_count(host, address)
                xrefs = '' if count is None else str(count)
            lines.append(f'| {_method_label(cls, kind, sel)} | {status} | {xrefs} | {length} |')
        (tree_path / name).write_text('\n'.join(lines) + '\n', encoding='utf-8')

    index_lines = [
        '# Reconstruction status',
        '',
        'Per-method status for every authored Objective-C method in the binary, split across files',
        'of at most 1000 rows. Compiler-emitted `.cxx_destruct` and synthesised property accessors',
        'are excluded; hand-written accessors are kept. Generated by `tools/status_tables_gen.py`.',
        '',
        f'**{done} of {total} authored methods written ({done * 100.0 / total:.1f}%).**',
        '',
        '| File | Classes | Methods |',
        '| ---- | ------- | ------- |',
    ]
    for name, first_class, last_class, count in generated_files:
        index_lines.append(f'| [{name}]({name}) | `{first_class}` – `{last_class}` | {count} |')
    (tree_path / 'STATUS.md').write_text('\n'.join(index_lines) + '\n', encoding='utf-8')

    print(f'wrote STATUS.md and {file_count} table file(s): {done}/{total} written')
    print(f'xref column populated: {xref_reachable}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
