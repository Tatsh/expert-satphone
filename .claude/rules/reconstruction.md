# Reconstruction methodology

This tree reconstructs a decompiled binary. These rules govern how to translate Ghidra output into
faithful C, C++, and Objective-C. The coding style of the resulting source lives in
[c-cpp-objc.md](c-cpp-objc.md); this file is about getting from the binary to that source correctly.

- Tie a reconstructed routine to its binary function with the `@ghidraAddress 0x...` Doxygen tag (a
  custom tag in our Doxygen configuration) on its header declaration; the address is relative to the
  program's image base. In an implementation file this tag appears only inside a block body (see the
  Objective-C block rule in `c-cpp-objc.md`).
- Keep the binary's names. Reconstructed globals keep their Ghidra names (for example the
  `g_`-prefixed globals). Ghidra placeholder names (`FUN_*`, `DAT_*`, `PTR_*`) are never used as
  identifiers in reconstructed code; rename them descriptively and record the address with
  `@ghidraAddress`.
- Assume every Ghidra "free function" is really a class method until proven otherwise. First test
  whether it is an instance method: a pointer argument (in any position, not only the first) that the
  function treats as its object — reads/writes that object's fields, or is the receiver the name
  implies — makes it an instance method of that object's class (`obj->Method(otherArgs)`). If no
  argument is an object receiver, test whether it is a static method: does it construct, vend, or
  operate on one specific class (a `Class::shared()` singleton getter, a factory, a table/among a
  family keyed to one class)? Place it as a `static` member of that class. Only after both searches
  are exhausted — no receiver argument and no owning class — may it be reconstructed as a genuine
  free function. Singleton getters are always static methods named `shared()` on the vended class.
- Take a C++ class's name from its RTTI when RTTI is present: the Itanium `type_info` name string
  (and the demangled vtable/`type_info` symbol) is authoritative — use it verbatim as the class
  name, exactly as an Objective-C class name comes from the runtime metadata. When there is no RTTI
  (a non-polymorphic class emits none), name the class from its embedded `__FILE__` basename and its
  method/`__func__` names instead, and note that the name is inferred rather than RTTI-confirmed.
- Model real types, not decompiler artifacts. Use real struct fields (never `field_0xNN`) and real
  pointer, enum, and `BOOL` types (never `void *` for a typed pointer, an `int` that holds a
  pointer, or `undefined`/`undefined4`).
- Document the original 32-bit struct layout with trailing `// +0xNN` offset comments, but treat
  those offsets as documentation only: do not `#pragma pack` or `static_assert` the layout, and
  never read or write a struct by a hardcoded offset. The 32-bit offsets do not hold on the 64-bit
  target, so always go through named fields.
- `reinterpret_cast` is a smell: it usually hides a type or signature bug, especially a
  function-pointer callback ABI. Prefer real types and typed access, and replace such casts at crash
  sites. `void *` is likewise a major smell: use it only for a genuinely opaque raw byte buffer (for
  example the `const void *` data argument of an MD5 helper), never for a typed engine object — those
  get their real class type.
- Recover the true function signature. A Ghidra decompile that uses `in_*` pseudo-variables (for
  example `in_w1`, `in_x2`, `in_stack_*`), or lists them under its Parameters, is missing formal
  parameters: the function takes arguments the decompiler did not bind into the prototype. Never
  model such a function as taking fewer arguments than the `in_*` usage and the disassembly's
  register/stack reads prove (in particular, never as no-arg when it clearly is not) — fix the Ghidra
  prototype, then reconstruct the real signature. Scan for `in_*` whenever a signature looks empty.
- When reconstructing a C or C++ function you MUST get its signature correct first (per the `in_*`
  rule above), and then update ALL of its callers to match that corrected signature — both the
  Ghidra program (fix the prototype so every call site re-decompiles cleanly) and any already-written
  reconstructed source that calls it. A signature fix is not complete until every caller agrees with
  it; a corrected callee with stale callers is a defect, not a finished routine.
- When reconstructing a C or C++ function (or an Objective-C block), record its final signature in
  `tools/cxx_signatures.txt` in the same change: add or update the `0xADDRESS<tab>signature` line
  for that routine's image-relative address, using block syntax (for example `(^void)(int)`) for a
  block. `STATUS.md` reads this sidecar for its Signature column, and drops the routine from the
  outstanding list once the `@ghidraAddress` you add to the reconstructed source matches; regenerate
  it with `tools/status_tables_gen.py`. The list is only accurate if every reconstructed routine is
  annotated and signed as it lands.
- Fix the Ghidra program itself, not only the reconstructed source. As you work a function, in
  Ghidra: give every parameter, local, and return a real type (never a bare `long`/`int`/`undefined*`
  standing in for an object or struct pointer); rename every auto-named variable (`pnVar1`, `lVar2`,
  `uVar3`, `iVar4`, `pcVar5`, …) to a meaningful name; rename and type every `DAT_*`/`FUN_*`/`PTR_*`
  global as it is encountered; and create the real `struct`/`class` types so that offset-and-cast
  access (`*(int *)(in_x0 + i * 4 + 0x28)`) becomes a named field access (`p->nSpriteCount`). A
  function whose first argument is a pointer to a structure is almost always an instance method of
  that structure's class — model it as one. This applies even when the cast is taken _adjacent_ to
  an already-named field: `*(undefined1 *)((long)&x.field + 1) = 1` means a distinct field exists at
  that offset (or the neighbouring field is modelled wrong — for example a `ushort` that is really
  two bytes). Create or correct the struct field so the access is a clean named field; never leave
  such a cast behind.
- Flag surprising-but-faithful behaviour with a short comment so a reader does not mistake it for a
  reconstruction bug: a discarded return value, a call kept only for effect, a deliberate off-by-one,
  a value that looks wrong but matches the binary. Keep it terse — a trailing same-line comment where
  it fits, otherwise the line above (for example `(void)GetIsTallScreenFlag(); // Yes, the binary
discards this call's result.`). Do not write an extensive explanation.
- Scrutinise return values as hard as arguments: confirm the real return type and whether the value
  is actually returned/used (a discarded return, a returned `this`, or a bool-in-a-wider-register are
  all common), and fix the Ghidra prototype accordingly.
- The decompile is a guide, not the source of truth — verify against the disassembly. If a function
  shows any hint of NEON / vectorisation (SIMD `v`/`q` registers, `ld1`/`st1`, `fmla`, `tbl`, …),
  work it from the **disassembly only**: no guessing, no "best effort" reconstruction from the
  garbled decompile.
- **A variadic call must be reconstructed from the disassembly, never from the decompile.** Ghidra
  renders a variadic `objc_msgSend` with only its first variadic argument, because the rest are
  passed on the stack and the prototype does not describe them. The decompile is therefore not
  merely imprecise here, it is _silently truncated_, and a reconstruction written from it drops
  arguments while still compiling and running. Read the arm64 stack setup instead: the `stp`/`str`
  writes to `[sp, #…]` before the `bl` are the argument list in order, and a
  `stp xN,xzr,[sp, #…]` supplies the `nil` terminator, so the slot count is exact. Resolve each
  `kFoo`-style constant from the Mach-O indirect symbol table rather than from a decompiler label.
  This applies to every
  nil-terminated constructor (`dictionaryWithObjectsAndKeys:`, `initWithObjectsAndKeys:`,
  `arrayWithObjects:`, `setWithObjects:`, `UIAlertView`'s `otherButtonTitles:`) and to every
  format-style call (`stringWithFormat:`, `initWithFormat:`, `appendFormat:`, `NSLog`) whose format
  string is not a literal the compiler can check. An odd argument count in a pair-wise constructor,
  or a specifier count that exceeds the argument count, is a defect provable from the source alone.
- **The Objective-C phase follows the same five steps as the engine phase below, and for the same
  reason.** The view and controller classes were originally reconstructed without it, and the result
  is a recurring defect: the `@ghidraAddress` is right while the body is wrong. Specifically, a
  `CGRect`'s fields arrive transposed out of the soft-float shuffle, a per-idiom branch is collapsed
  to one arm so a pad gets the phone's metrics, or an arm is missed altogether. None of this is
  visible by reading the source, and none of it is caught by the compiler. So for each routine, in
  order: (1) read the decompile; (2) type it in Ghidra until it reads like ordinary Objective-C;
  (3) work from the disassembly for anything the decompiler garbles — every `CGRect`, `CGPoint`
  and `CGSize` argument, since those pass in `d0`–`d3` and the decompiler renders the shuffle as a
  pseudo-double; (4) write the reconstruction; (5) verify it against the disassembly.
- **A constant loaded from the pool must be decoded from the pool, not guessed from the decompile.**
  Most layout numbers reach the code as `adrp xN, <page>` followed by `ldr dM, [xN, #<offset>]`,
  which reads a `double` out of `__const`. The decompile frequently renders that as a pseudo-double,
  an integer, or nothing at all, so the value has to be read from the binary at
  `page + offset`. Two mistakes recur and both look plausible in the source: reading the _adjacent_
  pool slot, since these constants sit in dense runs eight bytes apart and a neighbouring value is
  usually in the same range; and taking an `fmov`'s immediate for a pool load or the reverse. Record
  the address the value came from in an `@ghidraAddress` comment on the declaration so the audit
  tool can re-check it later, and prefer one constant per address over reusing a name whose address
  you did not verify.
- **A frame must be checked for fit, not merely transcribed.** After recovering a frame, confirm it
  sits inside its container: a subview's `x + width` within the parent's width, and likewise for
  height. That one arithmetic check is what distinguishes a transposed `{width, height}` from a
  correct one, since both orders are individually plausible numbers. A recovered layout whose parts
  do not fit, or that leaves a container's width unaccounted for, has been misread.
- **Count the arms of every `IsPad()` and theme branch.** A `cbz`/`cbnz` on the result of `IsPad()`
  at `0x1a1200`, or on `[RBUserSettingData thema]`, marks a per-idiom or per-theme split, and a
  routine may branch three ways rather than two. Reconstruct every arm. A constant that exists in
  only one arm of the binary but is applied unconditionally in the reconstruction is a defect even
  when its value is right, because it is right for one device only.
- Run `rctool audit addresses <binary>` against the shipped binary after touching annotations. It
  checks every annotated method against the runtime metadata and every constant annotated on its
  declaration line against the bytes at that address. It cannot check a constant that carries no
  annotation, which is the large majority of them, so a clean run is necessary and not sufficient.
  `rctool` lives in the `recon-tools` repository beside this one; every audit, scan, and verify
  tool that used to sit in `tools/` is a subcommand now, grouped as `audit`, `objc`, `gen`,
  `dump`, `atlas`, and `ipa`. Pass `-W` to point it at a directory other than the current one.
  Only the `*_update.py` generators and `layout_table_gen.py` stay in `tools/`, because they are
  specific to this tree. The three record files `objc_update.py` reads are written by
  `rctool objc accessors|trivial|float-constants -o tools/<name>.txt`.
- The C/C++ engine phase is done one routine at a time as routines are encountered, never in batches.
  For each routine, in order: (1) read the decompile; (2) fix all typing in Ghidra until the
  decompile reads like normal C++ — the full signature, every local, the return, every global, and
  every struct it reads or writes (per the rules above); (3) if the routine shows any hint of NEON /
  vectorisation, from that point work the disassembly only; (4) write the reconstruction into
  `rbplus-src/`; (5) verify the reconstruction against the disassembly. It is slow but accurate, and
  it is a long task. Do not begin writing the equivalent code until the routine is well-typed.
  `InitializeBackgroundSceneNodes` is the reference example of the target state: it has been fully
  typed in Ghidra (real `this`/struct types, named struct fields, no `in_*`, no `pnVar1`/`lVar2`
  locals, no offset-with-cast access), so its decompile now reads like ordinary C++. Bring every
  engine routine to that same standard before reconstructing it.
- For a very large function body, save the decompiler output and the disassembler output to files,
  then break the function into parts by de-inlining the repeated or logically-distinct blocks into
  helper functions, and reconstruct using those helpers. Mark such helpers `inline` (not
  `__attribute__((always_inline))`) unless the block is genuinely performance-critical and you are
  certain the `always_inline` form will compile.
