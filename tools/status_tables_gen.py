"""Generate the reconstruction-status file listing the binary's outstanding routines.

Run from the recon-tools checkout so its modules are importable::

    uv run python /path/to/jubeat-src/tools/status_tables_gen.py \\
        /path/to/Jubeat.app/Jubeat /path/to/jubeat-src [--xrefs-host HOST:PORT] \\
        [--ignore FILE.m[,FILE2.m] ...]

``--ignore`` (repeatable, or a comma-separated list) drops source files by basename from the
"written" scan, so a file a background agent is still editing does not flip its routines to done
before it has been reviewed and integrated.

Writes a single ``STATUS.md`` holding only the routines still to reconstruct: the outstanding
Objective-C methods and, below them, the outstanding non-Objective-C C/C++ functions and
Objective-C block invoke bodies. Everything else in the binary is already reconstructed and audited,
so the file is a fixed, shrinking work list rather than an index of the whole binary.

Objective-C rows carry the method in ``-[ClassName selector]`` form, its Ghidra address, its
cross-reference count, and its byte length. The authored surface matches tools/progress.py:
compiler-emitted ``.cxx_destruct`` and synthesised property accessors are excluded; hand-written
accessors are kept.

C/C++ rows carry the function or block name, its Ghidra address, its cross-reference count, its byte
length, and its signature. The signature is read from the sidecar ``tools/cxx_signatures.txt``
(``0xADDRESS<tab>signature`` lines); a block's signature uses block syntax, e.g. ``(^void)(int)``.
Compiler-emitted block copy/destroy/byref helpers are excluded; the block invoke bodies and free
C/C++ functions are kept.

A routine counts as written (and so is dropped from the list) when the tree carries an
``@ghidraAddress`` matching its image-relative address for the C/C++ set, or a source body for the
Objective-C set. Cross-reference counts come from the Ghidra bridge's ``get_xrefs_to`` endpoint,
scoped to the Jubeat program; when the bridge is unreachable the count column is left blank.
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

_DEFAULT_HOST = 'localhost:8089'
_PROGRAM = 'Jubeat'
_SOURCE_SUFFIXES = ('.h', '.m', '.mm', '.cpp', '.c')
# A background agent works in a git worktree under this directory; its in-progress copy of the tree
# must never count toward the reconstructed surface until the work is integrated into the main tree.
_WORKTREES_DIR = 'worktrees'

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
        # Skip agent worktrees under .claude/worktrees: a background agent's in-progress copy of the
        # tree must not flip routines to done before its work is reviewed and integrated.
        if _WORKTREES_DIR in path.parts:
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


def _objc_outstanding_lines(authored, ends, xref_reachable, host):
    """Table rows for the Objective-C methods not yet written, in ascending address order."""
    lines = [
        '| Method | Ghidra address | # xrefs | Length |',
        '| ------ | -------------- | ------- | ------ |',
    ]
    for cls, kind, sel, address, written in authored:
        if written:
            continue
        relative = address - IMAGE_BASE
        end = ends.get(address)
        length = f'{end - address}' if end is not None else ''
        xrefs = str(_xref_count(host, address) or 0) if xref_reachable else ''
        lines.append(f'| {_method_label(cls, kind, sel)} | `0x{relative:x}` | {xrefs} | {length} |')
    return lines


def _cxx_outstanding_lines(rows, ends, signatures, annotated, xref_reachable, host):
    """Table rows for the C/C++ functions and blocks not yet written, in ascending address order."""
    lines = [
        '| Function | Ghidra address | # xrefs | Length | Signature |',
        '| -------- | -------------- | ------- | ------ | --------- |',
    ]
    for name_fn, address in rows:
        relative = address - IMAGE_BASE
        if relative in annotated:
            continue
        name_fn = _FUNCTION_NAME_OVERRIDES.get(relative, name_fn)
        end = ends.get(address)
        length = f'{end - address}' if end is not None else ''
        xrefs = str(_xref_count(host, address) or 0) if xref_reachable else ''
        signature = signatures.get(relative, '')
        signature_cell = f'`{signature}`' if signature else ''
        lines.append(f'| `{name_fn}` | `0x{relative:x}` | {xrefs} | {length} | {signature_cell} |')
    return lines


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
                      if body.path.name not in ignore
                      and _WORKTREES_DIR not in Path(body.path).parts}
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

    cxx_total = len(cxx_rows)
    cxx_done = sum(1 for _, address in cxx_rows if (address - IMAGE_BASE) in annotated)
    objc_outstanding = objc_total - objc_done
    cxx_outstanding = cxx_total - cxx_done

    lines = [
        '# Reconstruction status',
        '',
        'The routines still to reconstruct. Everything else in the binary is already reconstructed',
        'and audited, so this is a fixed, shrinking work list, not an index of the whole binary. A',
        'routine drops off once the tree carries its source body (Objective-C) or a matching',
        '`@ghidraAddress` (C/C++). Generated by `tools/status_tables_gen.py`.',
        '',
        f'**Objective-C: {objc_outstanding} of {objc_total} methods outstanding '
        f'({objc_done} written).**',
        f'**C/C++ and blocks: {cxx_outstanding} of {cxx_total} outstanding '
        f'({cxx_done} written).**',
        '',
        '## Objective-C methods',
        '',
    ]
    if objc_outstanding:
        lines += _objc_outstanding_lines(authored, ends, xref_reachable, host)
    else:
        lines.append('All Objective-C methods reconstructed.')
    lines += [
        '',
        '## C/C++ functions and blocks',
        '',
        'Compiler-emitted block copy/destroy/byref helpers and the third-party minizip `unz*` API',
        'are excluded. Signatures come from `tools/cxx_signatures.txt`.',
        '',
    ]
    if cxx_outstanding:
        lines += _cxx_outstanding_lines(cxx_rows, ends, signatures, annotated, xref_reachable, host)
    else:
        lines.append('All C/C++ functions and blocks reconstructed.')
    (tree_path / 'STATUS.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')

    print('wrote STATUS.md')
    print(f'  Objective-C: {objc_outstanding} outstanding of {objc_total} '
          f'({objc_done} written)')
    print(f'  C/C++ and blocks: {cxx_outstanding} outstanding of {cxx_total} '
          f'({cxx_done} written)')
    print(f'  xref column populated: {xref_reachable}; functions listed: {len(functions)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
