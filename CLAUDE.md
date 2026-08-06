# jubeat plus reconstruction memory

See @README.md for an overview of this project.

**Claude Code:** read this file, then [AGENTS.md](AGENTS.md), then `.claude/**` (rules) **before any
repository edit**, in the order and depth described in AGENTS.md (start with
[.claude/rules/general.md](.claude/rules/general.md)).

The Ghidra MCP server serves this binary as program **`Jubeat`**. Every MCP call must pass
`program="Jubeat"`; omitting it silently targets the sibling `rb458` program instead.
