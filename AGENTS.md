# Agents and AI guidance

All agent definitions, skills, and project rules live under **`.claude/`**. Use that tree whether you
use Claude Code, Cursor, GitHub Copilot, or another assistant: open or reference the files directly,
and use each product's own mechanics for attaching repo context where needed.

- **Hard prerequisite before any repository edit:** Read
  [.claude/rules/general.md](.claude/rules/general.md) in full (including _Before editing repository
  files_), then every other relevant `.claude/rules/*.md` for the paths you will change. Do this
  **before** creating, modifying, or deleting tracked files.
- If the user is only adding instructions for the assistant, **do not edit the repository** unless
  they ask for a concrete change.

## Rules (`.claude/rules/`)

| File                                            | Scope                                      |
| ----------------------------------------------- | ------------------------------------------ |
| [general](.claude/rules/general.md)             | Project-wide conventions                   |
| [reconstruction](.claude/rules/reconstruction.md) | Getting from the binary to correct source  |
| [c-cpp-objc](.claude/rules/c-cpp-objc.md)       | C, C++, and Objective-C style              |
| [json-yaml](.claude/rules/json-yaml.md)         | JSON and YAML files                        |
| [toml-ini](.claude/rules/toml-ini.md)           | TOML and INI files                         |
| [markdown](.claude/rules/markdown.md)           | Markdown files                             |

## Relationship to `rbplus-src`

This tree is the jubeat counterpart of the sibling `rbplus-src` reconstruction, and it inherits that
project's rules verbatim. The two binaries embed the same Konami "applilink" advertising SDK, so the
`Applilink*`, `Recommend*`, `Reward*`, and `AnalysisNetwork*` classes already reconstructed in
`rbplus-src/Project/` are a reference for the same classes here. They are a reference, not a source:
the two applications ship different builds of the SDK, so every method must still be read out of
this binary before it is written here.
