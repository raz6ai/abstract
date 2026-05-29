---
name: abstract-update
description: Pull the latest Abstract skills from GitHub and reinstall. Detects whether you have user-scoped, project-scoped, or both installs and updates each. Safe to run any time - the update is atomic per-skill. After running, restart Claude Code to pick up the new files.
---

# Abstract Update — Pull the latest Abstract skills

Refresh the Abstract skill family from https://github.com/raz6ai/abstract.

## Step 1: Detect installed scopes

```bash
USER_SCOPE_DIR="$HOME/.claude/skills"
PROJ_SCOPE_DIR="./.claude/skills"

HAS_USER=0
HAS_PROJ=0

[[ -d "$USER_SCOPE_DIR/abstract" ]] && HAS_USER=1
[[ -d "$PROJ_SCOPE_DIR/abstract" ]] && HAS_PROJ=1

echo "user-scoped: $HAS_USER"
echo "project-scoped: $HAS_PROJ"
```

If both are 0, tell the user:

> Abstract isn't installed in this environment. Run the install command from https://github.com/raz6ai/abstract first.

Then stop.

## Step 2: Pick scope to update

- If only one scope has Abstract installed, use that one. No question needed.
- If both scopes have it installed, use **AskUserQuestion**:

Question: `Abstract is installed in both scopes. Which to update?`
Header: `Update scope`
Options:
1. **Both** (Recommended) — update user-scoped and project-scoped.
2. **User-scoped only** — `~/.claude/skills/`.
3. **Project-scoped only** — `./.claude/skills/`.

## Step 3: Clone the latest

```bash
TMP="$(mktemp -d -t abstract-update.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/raz6ai/abstract "$TMP/abstract"
```

If the clone fails (network down, repo gone, git not installed), tell the user the error verbatim, clean up `$TMP`, and stop.

Capture the new version info:

```bash
cd "$TMP/abstract"
NEW_HASH=$(git rev-parse --short HEAD)
NEW_DATE=$(git log -1 --format=%cs)
NEW_MSG=$(git log -1 --format=%s)
cd - >/dev/null
```

## Step 4: Install for each chosen scope

For each scope the user picked, run install.sh with `ABSTRACT_INSTALL_DIR` pointing at the right skills directory:

```bash
# User-scoped
ABSTRACT_INSTALL_DIR="$HOME/.claude/skills" "$TMP/abstract/install.sh"

# Project-scoped (only if cwd has a .claude dir or the user explicitly chose this)
ABSTRACT_INSTALL_DIR="$(pwd)/.claude/skills" "$TMP/abstract/install.sh"
```

The install script overwrites each of the five skill folders (`abstract`, `abstract-history`, `abstract-config`, `abstract-rule`, `abstract-update`) and prints a line per skill.

## Step 5: Cleanup and confirm

The `trap` from Step 3 removes `$TMP` automatically when the skill finishes.

Tell the user:
- Which scope(s) were updated
- New version: `<NEW_HASH> (<NEW_DATE>) <NEW_MSG>`
- **Restart Claude Code to pick up the new skill files.** (Without a restart, Claude Code keeps the old skill descriptions cached.)

## Failure handling

- **Clone fails:** print the git error, leave existing install untouched, exit.
- **Install fails mid-copy:** install.sh uses `rm -rf` then `cp -r` per-skill. If a copy fails (disk full, permission), the affected skill folder may be empty. Print the error and recommend a re-run.
- **No network:** suggest checking connectivity, exit.

## When NOT to run

- During an active Claude Code session you care about preserving — restart the session after updating so the new skill content is loaded.
- If you've modified your local copy of any skill (custom tweaks to a SKILL.md). The update will overwrite your changes. Back up first.
