"""Generate per-routine reconstruction-status tables covering the binary's authored routines.

Run from the recon-tools checkout so its modules are importable::

    uv run python /path/to/jubeat-src/tools/status_tables_gen.py \\
        /path/to/Jubeat.app/Jubeat /path/to/jubeat-src [--xrefs-host HOST:PORT]

Writes STATUS_00.md, STATUS_01.md, ... for the Objective-C methods (grouped whole-class, at most
1000 rows per file), STATUS_06.md for the non-Objective-C C/C++ functions and Objective-C blocks,
and a STATUS.md index over them all.

Objective-C rows carry the method in ``-[ClassName selector]`` form, its Ghidra address, a status
tick, its cross-reference count, and its byte length. The authored surface matches
tools/progress.py: compiler-emitted ``.cxx_destruct`` and synthesised property accessors are
excluded; hand-written accessors are kept.

STATUS_06 rows carry the function or block name, its Ghidra address, a status tick, its
cross-reference count, its byte length, and its signature. The signature is read from the sidecar
``tools/cxx_signatures.txt`` (``0xADDRESS<tab>signature`` lines) so a regeneration preserves the
signatures curated as routines are reconstructed; a block's signature uses block syntax, e.g.
``(^void)(int)``. Compiler-emitted block copy/destroy/byref helpers are excluded; the block invoke
bodies and free C/C++ functions are kept.

A routine counts as written when the tree carries an ``@ghidraAddress`` matching its image-relative
address for the C/C++ set, or a source body for the Objective-C set. Cross-reference counts come
from the Ghidra bridge's ``get_xrefs_to`` endpoint, scoped to the Jubeat program; when the bridge is
unreachable the count column is left blank.
"""

import itertools
import re
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
_CXX_FILE_INDEX = 6
_DEFAULT_HOST = 'localhost:8089'
_PROGRAM = 'Jubeat'
_SOURCE_SUFFIXES = ('.h', '.m', '.mm', '.cpp', '.c')

# Free-function names that are compiler emissions rather than programmer-authored routines: the ARC
# block copy/destroy/byref helper pairs.
_COMPILER_FUNCTION_MARKERS = ('_BlockCopyHelper', '_BlockDestroyHelper', '_BlockByrefKeepHelper',
                              '_BlockByrefDestroyHelper')


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


def _annotated_addresses(tree_path):
    """Every image-relative address the tree tags with @ghidraAddress."""
    out = set()
    for path in tree_path.rglob('*'):
        if path.suffix not in _SOURCE_SUFFIXES:
            continue
        text = path.read_text(encoding='utf-8', errors='replace')
        for match in re.finditer(r'@ghidraAddress\s+0x([0-9a-fA-F]+)', text):
            out.add(int(match.group(1), 16))
    return out


def _load_signatures(tree_path):
    """Read the sidecar image-relative-address -> signature map, if present."""
    path = tree_path / 'tools' / 'cxx_signatures.txt'
    out = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '\t' not in line:
            continue
        address, signature = line.split('\t', 1)
        try:
            out[int(address, 16)] = signature.strip()
        except ValueError:
            continue
    return out


def _list_functions(host):
    """Return a list of (name, address) for every function Ghidra knows, or None when unreachable."""
    query = urllib.parse.urlencode({'program': _PROGRAM})
    try:
        with urllib.request.urlopen(f'http://{host}/list_functions?{query}', timeout=60) as response:
            body = response.read().decode('utf-8', 'replace')
    except (urllib.error.URLError, OSError):
        return None
    out = []
    for line in body.splitlines():
        match = re.match(r'^(.*) at ([0-9a-fA-F]+)$', line)
        if match:
            out.append((match.group(1), int(match.group(2), 16)))
    return out


def _method_label(cls, kind, sel):
    return f'`{kind}[{cls} {sel}]`'


def _write_objc_tables(tree_path, ends, chunks, file_count, xref_reachable, host):
    generated = []
    for file_index, chunk in enumerate(chunks):
        first_class, last_class = chunk[0][0], chunk[-1][0]
        name = f'STATUS_{file_index:02d}.md'
        generated.append((name, first_class, last_class, len(chunk)))
        lines = [
            f'# Reconstruction status {file_index + 1} of {file_count} (Objective-C)',
            '',
            f'Methods for classes `{first_class}` through `{last_class}`.',
            '',
            'Generated by `tools/status_tables_gen.py`; do not edit by hand.',
            '',
            '| Method | Ghidra address | Status | # xrefs | Length |',
            '| ------ | -------------- | ------ | ------- | ------ |',
        ]
        for cls, kind, sel, address, written in chunk:
            relative = address - IMAGE_BASE
            end = ends.get(address)
            length = f'{end - address}' if end is not None else ''
            xrefs = str(_xref_count(host, address) or 0) if xref_reachable else ''
            lines.append(f'| {_method_label(cls, kind, sel)} | `0x{relative:x}` | '
                         f'{"✅" if written else "❌"} | {xrefs} | {length} |')
        (tree_path / name).write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return generated


def _write_cxx_table(tree_path, rows, ends, signatures, annotated, xref_reachable, host):
    name = f'STATUS_{_CXX_FILE_INDEX:02d}.md'
    lines = [
        '# Reconstruction status (C/C++ functions and blocks)',
        '',
        'Every non-Objective-C routine Ghidra recovers in `__text`: free C/C++ functions and the',
        'Objective-C block invoke bodies. Compiler-emitted block copy/destroy/byref helpers are',
        'excluded.',
        '',
        'Generated by `tools/status_tables_gen.py`. Signatures come from `tools/cxx_signatures.txt`,',
        'filled in as routines are reconstructed.',
        '',
        '| Function | Ghidra address | Status | # xrefs | Length | Signature |',
        '| -------- | -------------- | ------ | ------- | ------ | --------- |',
    ]
    done = 0
    for name_fn, address in rows:
        relative = address - IMAGE_BASE
        written = relative in annotated
        if written:
            done += 1
        end = ends.get(address)
        length = f'{end - address}' if end is not None else ''
        xrefs = str(_xref_count(host, address) or 0) if xref_reachable else ''
        signature = signatures.get(relative, '')
        signature_cell = f'`{signature}`' if signature else ''
        lines.append(f'| `{name_fn}` | `0x{relative:x}` | {"✅" if written else "❌"} | '
                     f'{xrefs} | {length} | {signature_cell} |')
    (tree_path / name).write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return name, done, len(rows)


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
    written_bodies = set(source_bodies(tree_path))
    annotated = _annotated_addresses(tree_path)
    signatures = _load_signatures(tree_path)

    # Byte lengths come from the gap to the next routine, over the union of every routine's start so
    # that a C function following an Objective-C method (or vice versa) still gets a correct bound.
    text = binary.section('__text')
    text_start, text_end = text.address, text.address + text.size
    functions = _list_functions(host) or []
    all_starts = sorted(set(methods.values())
                        | {address for _, address in functions if text_start <= address < text_end})
    ends = dict(itertools.pairwise(all_starts))

    hand_written = _hand_written_accessors(binary, methods, properties, ends)

    # Objective-C authored methods, grouped by class.
    by_class = defaultdict(list)
    for (cls, kind, sel), address in methods.items():
        if sel in _COMPILER_GENERATED:
            continue
        if _is_accessor(sel, properties.get(cls, {})) and (cls, kind, sel) not in hand_written:
            continue
        by_class[cls].append((kind, sel, address))

    chunks = []
    current = []
    objc_total = objc_done = 0
    for cls in sorted(by_class, key=str.lower):
        rows = []
        for kind, sel, address in sorted(by_class[cls], key=lambda row: row[2]):
            written = (cls, kind, sel) in written_bodies
            rows.append((cls, kind, sel, address, written))
            objc_total += 1
            objc_done += 1 if written else 0
        if current and len(current) + len(rows) > _ROWS_PER_FILE:
            chunks.append(current)
            current = []
        current.extend(rows)
    if current:
        chunks.append(current)
    objc_file_count = len(chunks)

    # Non-Objective-C routines: free C/C++ functions and block invoke bodies, minus the compiler's
    # block-helper pairs. Ordered by address.
    objc_addresses = set(methods.values()) | set(binary.category_map().values())

    def is_compiler_function(fn_name):
        return any(marker in fn_name for marker in _COMPILER_FUNCTION_MARKERS)

    cxx_rows = sorted(
        ((fn_name, address) for fn_name, address in functions
         if text_start <= address < text_end
         and address not in objc_addresses
         and not is_compiler_function(fn_name)),
        key=lambda row: row[1])

    xref_reachable = _xref_count(host, IMAGE_BASE + 0x480c) is not None

    generated = _write_objc_tables(tree_path, ends, chunks, objc_file_count, xref_reachable, host)
    cxx_name, cxx_done, cxx_total = _write_cxx_table(
        tree_path, cxx_rows, ends, signatures, annotated, xref_reachable, host)

    index_lines = [
        '# Reconstruction status',
        '',
        'Per-routine status for every authored routine in the binary. The `STATUS_0N.md` files hold',
        "the Objective-C methods (compiler-emitted `.cxx_destruct` and synthesised accessors",
        'excluded, hand-written accessors kept); `STATUS_06.md` holds the C/C++ functions and',
        'Objective-C blocks. Generated by `tools/status_tables_gen.py`.',
        '',
        f'**Objective-C: {objc_done} of {objc_total} methods written '
        f'({objc_done * 100.0 / objc_total:.1f}%).**',
        f'**C/C++ and blocks: {cxx_done} of {cxx_total} written '
        f'({cxx_done * 100.0 / cxx_total:.1f}%).**',
        '',
        '| File | Contents | Rows |',
        '| ---- | -------- | ---- |',
    ]
    for name, first_class, last_class, count in generated:
        index_lines.append(f'| [{name}]({name}) | `{first_class}` – `{last_class}` | {count} |')
    index_lines.append(f'| [{cxx_name}]({cxx_name}) | C/C++ functions and blocks | {cxx_total} |')
    (tree_path / 'STATUS.md').write_text('\n'.join(index_lines) + '\n', encoding='utf-8')

    print(f'wrote STATUS.md, {objc_file_count} Objective-C table(s), and {cxx_name}')
    print(f'  Objective-C: {objc_done}/{objc_total}; C/C++ and blocks: {cxx_done}/{cxx_total}')
    print(f'  xref column populated: {xref_reachable}; functions listed: {len(functions)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
