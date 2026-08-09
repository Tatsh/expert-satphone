"""Generate per-routine reconstruction-status tables covering the binary's authored routines.

Run from the recon-tools checkout so its modules are importable::

    uv run python /path/to/jubeat-src/tools/status_tables_gen.py \\
        /path/to/Jubeat.app/Jubeat /path/to/jubeat-src [--xrefs-host HOST:PORT] \\
        [--ignore FILE.m[,FILE2.m] ...]

``--ignore`` (repeatable, or a comma-separated list) drops source files by basename from the
"written" scan, so a file a background agent is still editing does not flip its routines to done
before it has been reviewed and integrated.

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
from pathlib import Path

import recon_tools.objc as _objc
from recon_tools.arm64 import INSTRUCTION_SIZE, body_length, branch_target, is_branch_with_link
from recon_tools.macho import IMAGE_BASE, MachOBinary
from recon_tools.objc import TRIVIAL_INSTRUCTIONS, source_bodies

# recon_tools.objc caps how far a method signature may wrap before its opening brace at eight
# lines, which drops a body whose selector is kept one keyword per line past that (for example the
# ten-part ``requestAsynchronousWithURL:...`` definition), so those methods never flip to written
# even though they carry a matching @ghidraAddress. The package is a read-only dependency here, so
# raise the cap in place before parsing any bodies.
_objc._SIGNATURE_LINES = 16

# Never written by hand, so never part of the authored surface. ARC emits .cxx_destruct to release
# a class's strong ivars and it has no source form at all.
_COMPILER_GENERATED = ('.cxx_destruct',)


def _super_only_deallocs(binary, methods, ends):
    """
    Find every -dealloc whose whole body is a single `[super dealloc]` call.

    Under this tree's ARC-only rule such a dealloc has no hand-written form -- `[super dealloc]`
    cannot be written -- so, like .cxx_destruct, it is not authored work. A dealloc that also
    releases ivars or clears a weak reference makes more than one `bl` and stays in scope. The test
    is structural (exactly one branch-with-link, to the shared super-dealloc trampoline) rather than
    size-based, so it never mistakes a real dealloc for a trampoline.
    """
    trampolines = {address for (_, _, sel), address in methods.items() if sel == 'dealloc'}
    # The one call target every trampoline dealloc shares is objc_msgSendSuper2's stub; learn it
    # from the deallocs themselves as the target reached by a lone bl.
    lone_targets = {}
    for (cls, kind, sel), address in methods.items():
        if sel != 'dealloc':
            continue
        end = ends.get(address)
        if end is None:
            continue
        calls = []
        for offset in range(address, end, INSTRUCTION_SIZE):
            word = binary.word_at(offset) & 0xFFFFFFFF
            if is_branch_with_link(word):
                calls.append(branch_target(word, offset))
        if len(calls) == 1:
            lone_targets.setdefault(calls[0], 0)
            lone_targets[calls[0]] += 1
    if not lone_targets:
        return set()
    trampoline_target = max(lone_targets, key=lone_targets.get)
    out = set()
    for (cls, kind, sel), address in methods.items():
        if sel != 'dealloc':
            continue
        end = ends.get(address)
        if end is None:
            continue
        calls = [
            branch_target(binary.word_at(offset) & 0xFFFFFFFF, offset)
            for offset in range(address, end, INSTRUCTION_SIZE)
            if is_branch_with_link(binary.word_at(offset) & 0xFFFFFFFF)
        ]
        if calls == [trampoline_target]:
            out.add((cls, kind, sel))
    return out

_ROWS_PER_FILE = 1000
_CXX_FILE_INDEX = 6
_DEFAULT_HOST = 'localhost:8089'
_PROGRAM = 'Jubeat'
_SOURCE_SUFFIXES = ('.h', '.m', '.mm', '.cpp', '.c')

# Free-function names that are compiler emissions rather than programmer-authored routines: the ARC
# block copy/destroy/byref helper pairs.
_COMPILER_FUNCTION_MARKERS = ('_BlockCopyHelper', '_BlockDestroyHelper', '_BlockByrefKeepHelper',
                              '_BlockByrefDestroyHelper')

# Third-party functions this tree will not reimplement: the minizip unz* API is used as-is from the
# real library, so it is not part of the reconstruction surface.
_EXCLUDED_FUNCTION_PREFIXES = ('unz',)

# Display-name overrides for routines whose Ghidra label is not the reconstructed name. The
# LC_MAIN target is the app's own main(); the BFCodecContext C API is modelled as that C++ class's
# members (constructor, destructor, and instance methods).
_FUNCTION_NAME_OVERRIDES = {
    0x7b08: 'main',
    0x93b34: 'BFCodecContext::BFCodecContext',
    0x93b64: 'BFCodecContext::~BFCodecContext',
    0x93b70: 'BFCodecContext::clear',
    0x93b88: 'BFCodecContext::setKey',
    0x93db0: 'BFCodecContext::encipherBlock',
    0x93e28: 'BFCodecContext::decipherBlock',
}


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


def _annotated_addresses(tree_path, ignore=frozenset()):
    """Every image-relative address the tree tags with @ghidraAddress.

    Source files whose basename is listed in ``ignore`` are skipped, so a partially written file
    (for example one a background agent is still editing) does not flip its routines to done before
    it has been reviewed and integrated.
    """
    out = set()
    for path in tree_path.rglob('*'):
        if path.suffix not in _SOURCE_SUFFIXES:
            continue
        if path.name in ignore:
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
        first_relative = chunk[0][3] - IMAGE_BASE
        last_relative = chunk[-1][3] - IMAGE_BASE
        name = f'STATUS_{file_index:02d}.md'
        generated.append((name, first_relative, last_relative, len(chunk)))
        lines = [
            f'# Reconstruction status {file_index + 1} of {file_count} (Objective-C)',
            '',
            f'Methods at Ghidra addresses `0x{first_relative:x}` through `0x{last_relative:x}`, '
            'in ascending address order.',
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
        'excluded, as is the third-party minizip `unz*` API (used as-is, not reimplemented).',
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
        name_fn = _FUNCTION_NAME_OVERRIDES.get(relative, name_fn)
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
    # Source-file basenames to exclude from the "written" scan. Repeatable; also accepts a single
    # comma-separated value. Use it to keep a file a background agent is still editing from flipping
    # its routines to done before the file has been reviewed and integrated.
    ignore = set()
    while '--ignore' in args:
        index = args.index('--ignore')
        ignore.update(part for part in args[index + 1].split(',') if part)
        del args[index:index + 2]
    binary_path, tree_path = Path(args[0]), Path(args[1])

    binary = MachOBinary(binary_path)
    methods = binary.method_map()
    properties = binary.property_map()
    written_bodies = {key
                      for key, body in source_bodies(tree_path).items()
                      if body.path.name not in ignore}
    annotated = _annotated_addresses(tree_path, ignore)
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
    super_only_deallocs = _super_only_deallocs(binary, methods, ends)

    # Objective-C authored methods, ordered by ascending Ghidra address and split into fixed-size
    # files.
    authored = []
    for (cls, kind, sel), address in methods.items():
        if sel in _COMPILER_GENERATED:
            continue
        if (cls, kind, sel) in super_only_deallocs:
            continue
        if _is_accessor(sel, properties.get(cls, {})) and (cls, kind, sel) not in hand_written:
            continue
        authored.append((cls, kind, sel, address, (cls, kind, sel) in written_bodies))
    authored.sort(key=lambda row: row[3])
    objc_total = len(authored)
    objc_done = sum(1 for row in authored if row[4])

    chunks = [authored[i:i + _ROWS_PER_FILE] for i in range(0, len(authored), _ROWS_PER_FILE)]
    objc_file_count = len(chunks)

    # Non-Objective-C routines: free C/C++ functions and block invoke bodies, minus the compiler's
    # block-helper pairs. Ordered by address.
    objc_addresses = set(methods.values()) | set(binary.category_map().values())

    def is_compiler_function(fn_name):
        return any(marker in fn_name for marker in _COMPILER_FUNCTION_MARKERS)

    def is_excluded_function(fn_name):
        return fn_name.startswith(_EXCLUDED_FUNCTION_PREFIXES)

    cxx_rows = sorted(
        ((fn_name, address) for fn_name, address in functions
         if text_start <= address < text_end
         and address not in objc_addresses
         and not is_compiler_function(fn_name)
         and not is_excluded_function(fn_name)),
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
    for name, first_relative, last_relative, count in generated:
        index_lines.append(f'| [{name}]({name}) | Methods `0x{first_relative:x}` – '
                           f'`0x{last_relative:x}` | {count} |')
    index_lines.append(f'| [{cxx_name}]({cxx_name}) | C/C++ functions and blocks | {cxx_total} |')
    (tree_path / 'STATUS.md').write_text('\n'.join(index_lines) + '\n', encoding='utf-8')

    print(f'wrote STATUS.md, {objc_file_count} Objective-C table(s), and {cxx_name}')
    print(f'  Objective-C: {objc_done}/{objc_total}; C/C++ and blocks: {cxx_done}/{cxx_total}')
    print(f'  xref column populated: {xref_reachable}; functions listed: {len(functions)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
