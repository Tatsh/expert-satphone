# C/C++/Objective-C guidelines

## General

- One class per header and per implementation file: each Objective-C `@interface`/`@implementation`
  and each C++ `class`/`struct` with methods gets its own `.h` and `.m`/`.mm`/`.cpp`, named for that
  class. Do not aggregate several classes into one shared header. The engine bridge
  (`neEngineBridge.h`) and `neRenderer.h` predate this rule and must be split into per-class headers
  (each class moving to its own header, with the bridge retained only for genuinely free shared
  engine functions and globals, or dropped once empty). A file may contain small tightly-coupled
  helpers of its one class (a file-private struct, a delegate protocol it defines), but not a second
  independent class.
- Place a reconstructed source file in the subdirectory of `Project/` that mirrors the binary's
  embedded `__FILE__` path, with two elisions: drop the
  `/Users/.../Program/Games/REFLECBEAT/` prefix, and drop the `Classess/` path segment (a typo in
  the shipped tree — do not create a `Classess` directory). Keep the binary's original file
  basename verbatim, which is `snake_case` for the C++ engine/layer/model/scene files and the RB
  CamelCase name for the view/UI files. Examples:
  `.../Classess/OpenGL/Layer/Classic/full_combo_classic_layer.mm` →
  `Project/OpenGL/Layer/Classic/full_combo_classic_layer.mm`;
  `.../Classess/Views/Music/RBMusicView.mm` → `Project/Views/Music/RBMusicView.mm`;
  `.../GameSystem/src/OpenGL/neGLES.cpp` → `Project/GameSystem/src/OpenGL/neGLES.cpp`. A file with
  no embedded path stays at the `Project/` root.
- 4 space indents with no tabs. This overrides the repository-wide 2-space default in
  [general.md](general.md): every C, C++, and Objective-C source and header file (`.c`, `.h`, `.m`,
  `.mm`, `.cpp`) is indented with 4 spaces, never 2. The 2-space default applies only to the
  non-C-family files (JSON, YAML, TOML, Markdown, and similar).
- Avoid magic numbers: create constants and enumerations for all numbers that are not obvious (e.g.,
  `kMaxPlayers` instead of `4`). This includes creating enumerations for array indices and bit
  flags that carry meaning (for example `scaledSize[kVectorComponentX]`, not `scaledSize[0]`).
- A bare small integer is acceptable when it is structural rather than meaningful: a trivial array
  index that carries no domain value (`items[0]`, `pair[1]`, and the `[0]` inside `ARRAY_SIZE`), an
  emptiness or length test (`.length == 0`, `.count != 1`), a loop start, or a boolean-like `0`/`1`
  return. Do not replace these — leave existing trivial `[0]`/`[1]`/`[2]`/… index accesses as they
  are. Only when a literal instead encodes a domain value (a mode, a type, a named index, a sentinel
  identifier) must it become a named constant or enumeration value.
- By default use decimal integer literals unless hex is required for bitwise operations or when it
  genuinely aids readability.
- Declare an array that has an initialiser list without an explicit size, letting the element count
  be inferred: `int x[] = {1, 2, 3};`, not `int x[3] = {1, 2, 3};`. Give the size only when it
  clarifies intent (for example a fixed-length buffer whose length matters independently of the
  initialiser).
- Use `.h` extension for all headers regardless of language.
- Include grouping: the file's own header first, then system, first party (Apple, etc), third party,
  and ours (in double quotes). Each group is separated by a single blank line:

  ```c
  #import "ThisFile.h"

  #include <memory>

  #include <CoreFoundation/CoreFoundation.h>

  #include <OtherThirdParty.h>
  #include <TouchJSON.h>

  #include "OurFile.h"
  ```

  `clang-format` enforces this (`IncludeBlocks: Regroup`): it moves the file's own header to the top
  and inserts the blank line between each group. This project should not have anything that requires
  a specific header order beyond this.

- Keep all header groups sorted alphabetically.
- Use `clang-format` to format source files. Shortcut: `yarn format`.
- This project uses Doxygen to document members. Always document public members in headers.
- Use plain `//` comments for internal and file-private commentary (implementation notes, file-scope
  constants, and other non-public code). Reserve Doxygen — a `/** ... */` block with `@brief`,
  `@param`, `@return`, `@ghidraAddress`, etc. — for public members declared in headers. Do not use
  the `///` Doxygen single-line form for internal comments.
- Document a public enumeration's members with a trailing Doxygen member comment (`/*!< ... */`) on
  the same line as the member, not a leading comment before it:

  ```objc
  typedef NS_ENUM(NSInteger, ScoreDataFrameBonusType) {
      ScoreDataFrameBonusTypeNone = 0,   /*!< No frame bonus. */
      ScoreDataFrameBonusTypeBronze = 1, /*!< The first (lower) frame-bonus tier. */
      ScoreDataFrameBonusTypeGold = 2,   /*!< The second (higher) frame-bonus tier. */
  };
  ```

- Use attached braces. `if () {` not `if ()\n{`.
- _Always_ include curly braces.
- Use parentheses to group expressions.
- When an assignment appears in a condition, wrap it in double parentheses (e.g.
  `if ((p = next()))`); generally avoid assignment inside conditions.
- `*` go to the right of the type. `int *a` not `int* a`.
- Prefer to use pre-increments: `++i` not `i++`.
- Always keep `theos/Makefile` synced with the `CMake` files.
- If a structure member is a bit-field, declare the width (number of bits).
- Use British spelling in comments and documentation; use American spelling for identifiers.
- Use the boolean type native to each language and never mix them. Pure C++ (a `.cpp`, or the C++
  portion of a `.mm` or `.h`) uses `bool` with `true`/`false` — never `BOOL` and never the bare
  `_Bool`. Pure C uses `bool` from `<stdbool.h>` (include it) with `true`/`false` — again never
  `BOOL` or a bare `_Bool`. Objective-C uses `BOOL` with `YES`/`NO`. Match the language of the
  surrounding code, not the language the field is shared with: a `bool` engine field read from
  Objective-C stays `bool` in the C++ header and is used as a truthy value from the Objective-C
  side.

## C

- Use `#ifndef UPPERCASE_NAME_H` (all-caps) header guards.
- Use `snake_case` for identifiers.
- Wrap C headers in `extern "C"` (guarded by `#ifdef __cplusplus`) so their symbols are not subject
  to C++ name mangling.

## C++

- Use `#pragma once` as the header guard.
- Use `#ifdef __OBJC__` to wrap Objective-C++ code in C++ unless the implementation file extension
  is `.mm` (Objective-C++). This allows the header to be included in pure C++ files without errors.
- Liberally use `auto` and `const auto&` for type inference, especially for iterators and STL
  containers.
- Use the `.cpp` extension only for pure C++ (no Objective-C). Any file that mixes C++ with
  Objective-C uses `.mm`; any header that declares C++ used from Objective-C is `.h` (see the
  `#ifdef __OBJC__` rule above).
- Name classes in CamelCase where acronyms become title-case (ID becomes Id).
- If a class name is available in the RTTI use it for the name.
- `delete` is only used when it is what the original did and the same behaviour cannot be achieved
  with smart pointers. Otherwise smart pointers are highly encouraged.
- Always use C++-style casts in `.mm` and `.cpp` (and C++ headers): `static_cast`, `reinterpret_cast`
  (a smell — see above), `const_cast`, `dynamic_cast`. Never a C-style `(type)expr` cast there.
- `*` and `&` go to the right of the type. `int &a` not `int& a`.
- Use `__builtin_available()` to check for API availability. Prefer runtime checks over
  compile-time.
- Use `= {}` to zero initialise class members.
- Use `m_` prefix to name class members.
- Prefer to use zero-init constructors whenever possible.
- Initialise a variable with a braced list using direct-list-initialization, without the `=`:
  `S_VECTOR2 size{x, y};`, not `S_VECTOR2 size = {x, y};`.
- A compile-time numeric or size constant is a `constexpr`, not a `static constexpr`: a
  namespace-scope (or file-scope) `constexpr` already has internal linkage, so the `static` is
  redundant — and it is especially pointless inside an anonymous `namespace {}`. Use
  `static NSString *const` for an Objective-C string constant (an `NSString *` is not a `constexpr`
  literal type).
- Declare a shared engine function exactly once, in the engine bridge header (`neEngineBridge.h`),
  and import that header where it is used; never re-declare the same engine prototype locally in
  several implementation files. A function whose first parameter is the object / `this` pointer
  (a `pThis`-style argument) is a C++ instance method — declare it as a member of its class (named
  from the RTTI where available), never as a free function that takes the object pointer.

## Objective-C

- Due to how Objective-C works at runtime, the binary documents all class, ivar, property, and
  method names. This project strictly uses those names.
- New code follows Apple's conventions: a class name gets a two-character prefix and all identifiers
  use `CamelCase` but retain all uppercase letters (`JSON` not `Json`).
- Private identifiers get a `_` prefix.
- Type an object as specifically as the binary allows. Prefer a concrete class (`RBMenuView *view`)
  over `id`, and where a value is only messaged through a protocol (a delegate or target), use a
  protocol-qualified `id<ProtocolName>` rather than a bare `id` (for example
  `id<RBMenuPageSliderDelegate> delegate`, not `id delegate`). Reserve a bare `id` for a genuinely
  untyped value the binary dispatches dynamically with no fixed protocol.
- This project uses ARC and has no support for Manual Reference Counting (MRC). Do not use `retain`,
  `release`, or `autorelease`. When the binary's MRC transfers ownership into a field (a `-copy` or
  `retain` that a later `release` balances), model it with a `strong` reference, not
  `__unsafe_unretained`.
- Null literals by language: use `nil` for Objective-C objects and `nullptr` for C and C++ pointers
  in `.mm`, `.cpp`, and `.h` files. Avoid `NULL`.
- Match an integer's spelling to its Objective-C metadata width encoding. A sub-64-bit integer uses
  a normal C type — `i` → `int`, `I` → `unsigned int`, `s`/`S` → `short`/`unsigned short`, `c`/`C` →
  `char`/`unsigned char` — never `NSInteger`/`NSUInteger` for these. A pointer-sized 64-bit integer
  (`q`/`Q`) uses the Cocoa typedef `NSInteger`/`NSUInteger`, not `long`/`unsigned long` or
  `long long`/`unsigned long long`. (Read the width from the `method_t` `types` string or the ivar/
  property encoding: `q`/`Q` are 8-byte, `i`/`I` are 4-byte.) This applies to an `NS_ENUM`/
  `NS_OPTIONS` backing too: back it with `int`/`unsigned int` when the ivar it types encodes as
  `i`/`I`, so the field keeps the binary's width. Apply this on any file you touch.
- Use `#import` for all imports.
- Use only Objective-C 2.0 constructs including properties, dot syntax, fast enumeration, blocks,
  and boxed literals.
- Prefer subscripting and boxed literals over the older messaging forms: `dict[key]` not
  `[dict objectForKey:key]`, `dict[key] = value` not `[dict setObject:value forKey:key]`, `arr[i]`
  not `[arr objectAtIndex:i]`, and `@(x)` not `[NSNumber numberWith…:x]`.
- Use `#pragma mark` (and `#pragma mark -` for a divider) to group an implementation into sections.
- Reconstruct getters and setters as `@property` declarations (add `@synthesize` only when the
  binary keeps a differently-named backing ivar), not spelled-out accessor bodies. Map the compiled
  accessor to its attribute: `assign`, `strong` (retain), or `copy`, and `atomic` or `nonatomic`.
- Reconstruct a singleton's shared instance as a method-local `static` inside the
  `+sharedManager`/`+sharedInstance`/`+getInstance` accessor, not a file-scope global or `static`.
  Reproduce the binary's own guarding exactly — `@synchronized(self)`, `dispatch_once`, or a plain
  `if (instance == nil)` nil-check — rather than imposing a different one.

  ```objc
  + (instancetype)sharedManager {
      static AudioManager *instance = nil;
      @synchronized(self) {
          if (instance == nil) {
              instance = [[AudioManager alloc] init];
          }
      }
      return instance;
  }
  ```

- Create an enumeration that is **declared in a header** with the macro that matches the
  enumeration's nature. This requirement is scoped to header declarations only: an enumeration or
  constant group defined in an implementation file (`.m`, `.mm`, `.cpp`, `.c`) does **not** use the
  `NS_*` macros — use a plain C/C++ `enum`, grouped `static NSString *const`, `static const`, or
  `static constexpr` there instead.
  - `NS_ENUM` for a simple integer-backed enumeration. Back it with the type matching the width and
    signedness of the ivar it types: `NSInteger`/`NSUInteger` for an 8-byte (`q`/`Q`) field, and
    `int`/`unsigned int` for a 4-byte (`i`/`I`) one. Do not pick a backing that widens the field
    beyond what the binary stores.
  - `NS_CLOSED_ENUM` for a simple enumeration that can never gain new cases.
  - `NS_OPTIONS` for an enumeration whose cases are bit-flag sets combined with `|`.
  - `NS_TYPED_ENUM` for an enumeration whose raw value is a type you specify. The raw type is
    whatever you name in the `typedef` — commonly `NSString *`, but any type works (for example
    `typedef long TrafficLightColor NS_TYPED_ENUM;`). A group of related string constants that forms
    an enumerated set (dictionary keys, archive/coder keys, a set of string-valued modes) is an
    `NS_TYPED_ENUM`, declared in the header and defined in the `.m`:

    ```objc
    // .h
    typedef NSString *RBCoderKey NS_TYPED_ENUM;
    extern RBCoderKey const RBCoderKeyVersion;
    extern RBCoderKey const RBCoderKeyScore;
    // .m
    RBCoderKey const RBCoderKeyVersion = @"ver";
    RBCoderKey const RBCoderKeyScore = @"score";
    ```

    A non-string typed enumeration follows the same shape, e.g.:

    ```objc
    // .h
    typedef long TrafficLightColor NS_TYPED_ENUM;
    extern TrafficLightColor const TrafficLightColorRed;
    extern TrafficLightColor const TrafficLightColorYellow;
    extern TrafficLightColor const TrafficLightColorGreen;
    // .m
    TrafficLightColor const TrafficLightColorRed = 0;
    TrafficLightColor const TrafficLightColorYellow = 1;
    TrafficLightColor const TrafficLightColorGreen = 2;
    ```

    Name the values `<TypeName><Value>` (no `k` prefix; they are typed extern globals, not file-local
    `static const`).

  - `NS_TYPED_EXTENSIBLE_ENUM` for such a typed enumeration you expect might gain more cases.
- Create constants with k-prefixes for global constants and static const for file-level constants.
  A group of related string values **exposed in a header** is an `NS_TYPED_ENUM` (see above), not
  loose `extern NSString *const` declarations; a file-private group in a `.m` may instead stay as
  grouped `static NSString *const` declarations. Use a standalone `static NSString *const` for a
  one-off string constant (a single URL, format, or passphrase).
- Annotate nullability on every Objective-C API. Mark each object pointer in a public declaration
  `nullable` or `nonnull` (parameters, return types, and property types), or wrap a header region in
  `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END` and annotate only the `nullable` exceptions.

  ```objc
  @interface MyList : NSObject
  - (nullable MyListItem *)itemWithName:(nonnull NSString *)name;
  - (nullable NSString *)nameForItem:(nonnull MyListItem *)item;
  @property (copy, nonnull) NSArray<MyListItem *> *allItems;
  @end
  ```

- Nullability annotations belong on the header declarations only. Do not repeat `nullable`/`nonnull`
  (or `_Nullable`/`_Nonnull`) on the corresponding method definitions in the implementation file, nor
  on a block-literal parameter whose type the framework already fixes.

- The macro-selection and nullability rules above are Objective-C only. They do not apply to C or
  C++ code (a `.cpp` file, or the C/C++ portions of a `.mm` or `.h`); use plain `enum`/`enum class`
  and C/C++ types there.
- Use `@available()` to check for API availability. Prefer runtime checks over compile-time.
- Headers only: add modelines to the end of the file. Do **not** add modelines to an
  implementation file (`.m`, `.mm`, `.cpp`, `.c`); they belong solely in headers.

  ```objc
  // code: language=Objective-C
  // kate: hl Objective-C;
  // vim: set ft=objc :
  ```

  Use `language=Objective-C++`, `hl Objective-C++`, and `ft=objcpp` for Objective-C++ headers.

- When a `UIColor` is built from components (`colorWithRed:green:blue:alpha:` or
  `colorWithWhite:alpha:`) that exactly equal one of Apple's predefined class colours, use that
  predefined colour instead of the spelled-out component call, and add a short comment noting the
  original used the full component call. The predefined colours are `blackColor` (0,0,0,1),
  `blueColor` (0,0,1,1), `brownColor`, `cyanColor` (0,1,1,1), `darkGrayColor` (1/3 white),
  `grayColor` (1/2 white), `greenColor` (0,1,0,1), `lightGrayColor` (2/3 white), `magentaColor`
  (1,0,1,1), `orangeColor`, `purpleColor`, `redColor` (1,0,0,1), `whiteColor` (1,1,1,1), and
  `yellowColor` (1,1,0,1). Only substitute when the components match exactly; leave other component
  colours as the full call.
- Access the predefined `UIColor` class colours with dot syntax, `UIColor.whiteColor`, not the
  bracket message form `[UIColor whiteColor]` — property/dot access is preferred wherever possible
  (see the Objective-C 2.0 rule above). This applies to the zero-argument class-colour accessors;
  component constructors that take arguments (`[UIColor colorWithRed:…]`) stay in message form.
- If a block is directly tied to a function in the binary, use `@ghidraAddress 0x...` to document
  that.

  ```objc
  [doSomethingWithBlock:^{
    /** @ghidraAddress 0x1234 */
    // code here
  }]
  ```
