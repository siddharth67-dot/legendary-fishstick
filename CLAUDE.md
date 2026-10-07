# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state

This repository has no application code yet — it currently contains only Claude Code tooling configuration. There is no build, lint, or test setup to run.

## What's configured here

- **`.claude/skills/impeccable/`** — the Impeccable frontend design skill (from `pbakaus/impeccable`), installed manually by copying the skill/agent files and the compiled engine binary directly into the repo (not via `npx impeccable install`, which needs network access this environment's default policy blocks). The binary lives at `.claude/skills/impeccable/scripts/bin/linux-x64/impeccable` so the skill's launcher script (`.claude/skills/impeccable/scripts/impeccable`) can run it without a network fetch. Invoke the skill with `/impeccable <command> <target>` once a frontend project exists here (`init`, `craft`, `critique`, `audit`, `polish`, etc. — see `.claude/skills/impeccable/SKILL.md` for the full command list).
- **`.claude/agents/`** — four supporting agents for Impeccable (`impeccable-asset-producer`, `impeccable-documenter`, `impeccable-finish-reviewer`, `impeccable-manual-edit-applier`), used internally by the Impeccable skill's workflows.
- **`.mcp.json`** — registers the 21st.dev MCP server (`21st`), which provides UI component search and AI-assisted generation from the 21st.dev catalog. It authenticates via the `API_KEY_21ST` environment variable (not stored in the file) — set it in the environment's secrets for the server to connect.

## Note for future work

Once real application code is added to this repository, update this file with actual build/lint/test commands and the project's architecture — none exist yet to document.
