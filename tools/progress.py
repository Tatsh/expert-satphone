"""Report reconstruction progress against the binary's Objective-C metadata.

Run from the recon-tools checkout so its modules are importable::

    uv run python /path/to/jubeat-src/tools/progress.py \\
        /path/to/Jubeat.app/Jubeat /path/to/jubeat-src

Counts every method the runtime metadata declares, minus the ones no human wrote, against the
bodies present in the tree. Pass a class name to list that class's outstanding selectors.
"""

import itertools
import sys
from collections import defaultdict
from pathlib import Path

from recon_tools.arm64 import INSTRUCTION_SIZE, body_length, branch_target, is_branch_with_link
from recon_tools.macho import MachOBinary
from recon_tools.objc import TRIVIAL_INSTRUCTIONS, source_bodies

# Never written by hand, so never outstanding work. ARC emits .cxx_destruct to release a class's
# strong ivars and it has no source form at all.
_COMPILER_GENERATED = ('.cxx_destruct',)


def _super_only_deallocs(binary, methods, ends):
    """
    -dealloc methods whose whole body is a single `[super dealloc]` call.

    Under this tree's ARC-only rule such a dealloc has no hand-written form, so like .cxx_destruct
    it is not outstanding work. A dealloc that also releases ivars or clears a weak reference makes
    more than one `bl` and stays in scope.
    """
    lone_targets: dict[int, int] = {}
    for (_, _, sel), address in methods.items():
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
        if len(calls) == 1:
            lone_targets[calls[0]] = lone_targets.get(calls[0], 0) + 1
    if not lone_targets:
        return set()
    trampoline = max(lone_targets, key=lone_targets.get)
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
        if calls == [trampoline]:
            out.add((cls, kind, sel))
    return out


def _is_accessor(selector: str, properties: dict[str, str]) -> bool:
    if selector in properties:
        return True
    if selector.startswith('set') and selector.endswith(':') and len(selector) > 4:
        return selector[3].lower() + selector[4:-1] in properties
    return False


def _hand_written_accessors(binary: MachOBinary, methods: dict[tuple[str, str, str], int],
                            properties: dict[str, dict[str, str]]) -> set[tuple[str, str, str]]:
    """
    Find accessors the binary implements by hand rather than synthesising.

    Declaring a @property satisfies the *selector*, so an accessor normally costs no source and is
    correctly not work. But a class can implement one by hand, and then the whole routine is real
    work that a name-only test cannot see -- `ScoreRecordManager` was reported complete while three
    of its accessors, one of them 153 instructions, had never been written.

    Size is what separates the two, and the gap is wide: a synthesised accessor is a handful of
    instructions. The threshold is the same one `rctool objc property-accessors` uses.
    """
    addresses = sorted(set(methods.values()))
    following = dict(itertools.pairwise(addresses))
    out: set[tuple[str, str, str]] = set()
    for (cls, kind, sel), address in methods.items():
        if not _is_accessor(sel, properties.get(cls, {})):
            continue
        end = following.get(address)
        if end is None:
            continue
        if body_length(binary, address, (end - address) // INSTRUCTION_SIZE) > TRIVIAL_INSTRUCTIONS:
            out.add((cls, kind, sel))
    return out


def main() -> int:
    binary_path, tree_path = Path(sys.argv[1]), Path(sys.argv[2])
    only = sys.argv[3] if len(sys.argv) > 3 else None

    binary = MachOBinary(binary_path)
    methods = binary.method_map()
    properties = binary.property_map()
    written = {(cls, kind, sel) for cls, kind, sel in source_bodies(tree_path)}

    hand_written = _hand_written_accessors(binary, methods, properties)
    ends = dict(itertools.pairwise(sorted(set(methods.values()))))
    super_only_deallocs = _super_only_deallocs(binary, methods, ends)

    outstanding: dict[str, list[tuple[str, str, int]]] = defaultdict(list)
    total_real = 0
    for (cls, kind, sel), address in methods.items():
        if sel in _COMPILER_GENERATED:
            continue
        if (cls, kind, sel) in super_only_deallocs:
            continue
        if _is_accessor(sel, properties.get(cls, {})) and (cls, kind, sel) not in hand_written:
            continue
        total_real += 1
        if (cls, kind, sel) not in written:
            outstanding[cls].append((kind, sel, address))

    if only:
        rows = sorted(outstanding.get(only, []), key=lambda row: row[2])
        print(f'{only}: {len(rows)} outstanding')
        for kind, sel, address in rows:
            print(f'  {kind}{sel:52s} 0x{address - 0x100000000:x}')
        return 0

    done = total_real - sum(len(v) for v in outstanding.values())
    complete = [c for c in {cls for cls, _, _ in methods} if not outstanding.get(c)]
    print(f'methods: {done}/{total_real} written ({done * 100.0 / total_real:.1f}%)')
    print(f'classes: {len(complete)}/{len({cls for cls, _, _ in methods})} complete')
    print()
    print('closest to done:')
    for cls, rows in sorted(outstanding.items(), key=lambda kv: len(kv[1]))[:20]:
        print(f'  {cls:38s} {len(rows):4d} left')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
