---
name: abstract-config
description: First-run setup and reconfiguration for the Abstract skill family. Walks through arrow-key menus to pick where session recaps are written, whether to keep a separate lessons file, whether to scrub secrets from prompt history, and where rules from /abstract-rule should land. Run this once per project (or globally) before using /abstract.
---

# Abstract Config — Setup and Reconfiguration

Walk the user through setting up (or updating) the Abstract config file.

## Step 1: Detect existing config

Check both locations:
- `./.claude/abstract.config.json` (per-project)
- `~/.claude/abstract.config.json` (global)

If one or both exist, read the current values and use them as defaults in the questions below. Tell the user where the active config lives.

## Step 2: Pick destination

Use the **AskUserQuestion** tool. This renders an arrow-key-navigable list — it is the only interactive menu primitive available in Claude Code. Do not try to paint a TUI in the terminal.

Question: `Where should Abstract write your session recaps?`
Header: `Destination`
Options:
1. `./.claude/sessions` — Inside this project. Travels with the repo. (Recommended)
2. `./docs/sessions` — Inside this project's docs folder.
3. Sibling folder — Next to the project (you'll pick the name next).
4. Custom path — Absolute path, e.g. an Obsidian vault.

If the user picks **Sibling folder**, follow up with:

Question: `What should the sibling folder be called?`
Header: `Folder name`
Options: `notes`, `session-log`, `<project-name>-brain`, Other (user types).

If the user picks **Custom path** (or any "Other"), accept their input. Validate it can be created (`mkdir -p` it, or check absolute path is writable).

## Step 3: Pick options (3 questions in one AskUserQuestion call)

Ask all three together so the user sees them as one setup screen:

**Q1: Write a separate lessons file when 2+ lessons emerge?**
Header: `Lessons file`
- Yes (Recommended) — keeps reusable rules separate from session narrative.
- No — keep everything in the session file.

**Q2: Scrub secrets from prompt history?** (only affects `/abstract-history`)
Header: `Scrub secrets`
- Yes (Recommended) — redact API keys, tokens, credentials before writing.
- No — write prompts verbatim. Only safe if the project never sees secrets.

**Q3: Limit history transcripts to ~50k tokens?**
Header: `Token budget`
- Yes (Recommended) — summarize older assistant turns when transcripts get huge.
- No — write everything, however large.

## Step 4: Pick rules destination (if not already set)

If the config doesn't have a `rulesDestination` field yet, ask:

Question: `Where should /abstract-rule write project rules?`
Header: `Rules destination`
Options:
1. `./.claude/rules` — Standard Claude Code rules dir. (Recommended)
2. `./docs/rules` — Inside docs.
3. Custom path.

If the user hasn't run `/abstract-rule` yet, you may skip this step and let `/abstract-rule` ask on first invocation. Mention this to the user.

## Step 4.5: Manage domain taxonomy (for /abstract-compile)

Domains are the labels you can tag sessions with so `/abstract-compile` can synthesize per-domain playbooks (`abs-ui`, `abs-backend`, etc.). Setting up a taxonomy is optional — the rest of Abstract works without it.

Show the current `config.domains` if any exist. Then use **AskUserQuestion**:

Question: `Set up or modify your domain taxonomy?`
Header: `Domains`
Options:
1. **Use suggested defaults** — adds `ui`, `backend`, `auth`, `data`, `infra` to the config.
2. **Custom list** — you type a comma-separated list (e.g. `ui, api, data, ml`).
3. **Add to existing** — append new domains to whatever's already there.
4. **Remove some** — pick existing domains to delete (only shown if some exist).
5. **Skip / leave as-is** — keep whatever's in the config (or empty if nothing).

Follow-up questions depend on choice:
- Custom list / Add to existing: accept freeform comma-separated text. Trim whitespace, lowercase, kebab-case any spaces. Dedup against existing.
- Remove some: AskUserQuestion multiSelect of existing domains. Drop the picked ones.

Persist the final list as `config.domains`. If empty after edits, omit the field (or set to `[]`).

Tell the user what the final taxonomy is and that they can re-run `/abstract-config` any time to adjust it.

## Step 5: Pick scope

If the user picked a destination INSIDE the project (`./...`), default to per-project config (`./.claude/abstract.config.json`).

If they picked an absolute path (e.g. an Obsidian vault), ask:

Question: `Save this config per-project or globally?`
Header: `Config scope`
Options:
1. Per-project (`./.claude/abstract.config.json`) — recommended if recaps live inside the repo.
2. Global (`~/.claude/abstract.config.json`) — recommended if recaps go to a shared vault across projects.

## Step 6: Write the config

```json
{
  "version": 1,
  "destination": "<resolved path>",
  "rulesDestination": "<resolved path or null>",
  "domains": ["ui", "backend", "auth"],
  "writeLessons": true,
  "scrubSecrets": true,
  "historyTokenBudget": 50000
}
```

`domains` may be omitted entirely if the user hasn't set up a taxonomy. `/abstract-compile` will bootstrap it on first run if missing.

`mkdir -p` the parent directory if needed. Pretty-print the JSON (2-space indent).

## Step 7: Confirm

Tell the user:
- Path of the config file
- A one-line summary of each setting
- Next step: invoke `/abstract` to write a recap, `/abstract-history` for prompt history, `/abstract-rule` to generate rules from a session.
