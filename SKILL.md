---
name: abstract
description: Capture an end-of-session recap as a structured markdown note. Run at the end of a work session to record what changed, why, decisions made, and lessons learned. Supports subcommands - `/abstract` (standard recap), `/abstract history` (recap plus prompt history with summarized assistant outputs), `/abstract config` (reconfigure destination and options). On first run, walks the user through picking a destination folder.
---

# Abstract — Session Recap Skill

A portable session-recap skill. Writes a structured markdown note to a user-chosen folder so sessions compound into a searchable knowledge base.

## Subcommand dispatch

The user invokes this skill with optional args. Parse the first whitespace-separated token of the args:

| Token | Mode |
|-------|------|
| (empty) | **Standard recap** — section §A |
| `history`, `--history`, `-h` | **History recap** — section §B |
| `config`, `setup`, `reconfigure`, `--config` | **Config flow** — section §C |
| anything else | Treat as standard recap and ignore the unknown token |

Before running any mode, run the **Config resolution** step (§D). If no config is found, run the **First-run config flow** (§E) before continuing.

---

## §A. Standard recap (default)

### A.1 Gather context

Run these in parallel:

```bash
git diff --stat HEAD~5..HEAD 2>/dev/null || git diff --stat
git log --oneline -20 --no-merges
git status --short
git branch --show-current
```

Also review the conversation so far: what the user asked for, what was built, what went wrong, what was corrected.

### A.2 Classify the session

Pick one primary category. If none fit, use `other`.

- `feature` — new capability, page, or component
- `fix` — bug fix or correction
- `refactor` — restructuring without behavior change
- `migration` — data layer, API, infra, or framework migration
- `design` — UI/UX, design system, styling
- `config` — tooling, CI, settings, environment
- `docs` — documentation only
- `research` — exploration with no shipped change
- `other`

### A.3 Choose a slug

Short kebab-case description of the session (e.g. `auth-redirect-fix`, `tenant-modal-refactor`). Keep it under 40 chars. If a file already exists at the target path, append `-2`, `-3`, etc.

### A.4 Write the recap

Target path:
```
<destination>/sessions/YYYY-MM-DD-<slug>.md
```

Where `<destination>` is `config.destination` (resolved in §D) and `YYYY-MM-DD` is today's date.

Use this template exactly:

```markdown
---
date: YYYY-MM-DD
category: <one of A.2>
scope: [list of files, components, or systems touched]
tags: [domain tags — e.g. api, auth, typography]
---

# <Plain-English title of what was done>

## What changed
- Specific bullets. "Added X to Y" beats "updated Y".
- Reference files/components by name.

## Why
- The motivation: user request, bug report, prior session, deadline.

## Decisions made
- "Used X instead of Y because Z."
- Trade-offs accepted.

## Mistakes and corrections
- What went wrong in the session.
- What the assistant got wrong and had to redo.
- What the user corrected.
- Root cause of each — not just "fixed it".

## Patterns established
- New patterns future sessions should follow.
- Existing patterns reinforced.

## Lessons for next time
- Concrete, actionable rules that emerged.
- Format: **Rule:** <rule>. **Why:** <what goes wrong without it>.
```

### A.5 Optional lessons file

If the session produced 2+ concrete, non-obvious, reusable lessons AND `config.writeLessons` is `true`, also write:

```
<destination>/lessons/YYYY-MM-DD-<slug>.md
```

```markdown
---
date: YYYY-MM-DD
source_session: sessions/YYYY-MM-DD-<slug>.md
---

# Lessons: <topic>

## <Lesson title>
**Rule:** <actionable instruction>
**Why:** <what goes wrong without it>
**Example:** <before/after or concrete scenario>
```

Only write lessons that are **non-obvious and reusable**. "Don't forget semicolons" is noise. "API client unwraps the envelope once, so never write `query.data?.data`" is signal.

### A.6 Confirm

Tell the user:
- Path of the written file(s)
- How many lessons were captured
- Any lessons worth promoting to a project rules file (e.g. `.claude/rules/`)

---

## §B. History recap (`/abstract history`)

Same as standard recap, but ALSO append a `## Prompt history` section containing the actual user prompts and a summarized assistant response per turn.

### B.1 Locate the current transcript

Claude Code writes per-session JSONL transcripts to:
```
~/.claude/projects/<encoded-cwd>/<session-id>.jsonl
```

Where `<encoded-cwd>` is the current working directory with `/` replaced by `-`.

Find the active transcript:

```bash
ENCODED_CWD=$(pwd | sed 's|/|-|g')
TRANSCRIPT_DIR="$HOME/.claude/projects/$ENCODED_CWD"
LATEST=$(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1)
echo "$LATEST"
wc -l "$LATEST"
```

If `$LATEST` is empty, tell the user no transcript was found at `$TRANSCRIPT_DIR` and fall back to standard recap mode (§A).

### B.2 Read and parse turns

Each line of the JSONL is one event. The events you care about:
- User turns: `.type == "user"` with `.message.content` being a string or an array containing a `{type:"text", text:...}` block.
- Assistant turns: `.type == "assistant"` with `.message.content` being an array of blocks. Extract any `{type:"text", text:...}` blocks; ignore `{type:"tool_use"}` / `{type:"thinking"}` blocks for the dump (but you may mention "ran N tool calls" in the summary).

A reasonable extraction:

```bash
jq -c 'select(.type=="user" or .type=="assistant") | {type, content: (.message.content | if type=="string" then . else (map(select(.type=="text") | .text) | join("\n")) end)}' "$LATEST"
```

You may need to adjust the jq filter depending on Claude Code version. If the JSONL schema differs, read the first few lines (`head -3 "$LATEST" | jq .`) and adapt.

### B.3 Secret scrub

Before writing prompts into the recap file, run a redaction pass. Replace each match with `[REDACTED-<kind>]`:

| Pattern | Kind |
|---------|------|
| `sk-ant-[A-Za-z0-9_-]{20,}` | anthropic-key |
| `sk-[A-Za-z0-9]{20,}` | api-key |
| `AKIA[0-9A-Z]{16}` | aws-key |
| `ghp_[A-Za-z0-9]{36}`, `ghs_...`, `github_pat_...` | github-token |
| `Bearer\s+[A-Za-z0-9._-]{20,}` | bearer-token |
| `-----BEGIN [A-Z ]*PRIVATE KEY-----` | private-key |
| `(password\|passwd\|secret\|api[_-]?key)\s*[:=]\s*['"\`]?[^\s'"\`]{6,}` (case-insensitive) | credential |
| Any line from a `.env` file the session opened | env-value |

Count matches per kind. After scrubbing, tell the user: `Redacted N secrets (anthropic-key: 2, bearer-token: 1).` If `config.scrubSecrets` is `false`, skip this step and warn the user.

### B.4 Token budget

Skip if `config.historyTokenBudget` is unset. Otherwise, estimate token count of the parsed turns (rough rule: 4 chars per token). If over budget:
1. Keep all user prompts verbatim (those are the highest-signal part).
2. Summarize assistant turns more aggressively — replace long responses with one-line summaries: `Assistant: <one-sentence what it did>. <N> tool calls.`
3. If still over budget, drop the oldest tool-call-only assistant turns first.

Tell the user the final size and what was summarized.

### B.5 Output format

After the standard recap sections, append:

```markdown
## Prompt history

> Transcript: <basename of $LATEST>
> Turns: <user_count> user, <assistant_count> assistant
> Redactions: <N> (or "none")

### Turn 1 — User
<verbatim user prompt, after redaction>

### Turn 1 — Assistant
<one-paragraph summary of what the assistant did and said; mention tool calls if any>

### Turn 2 — User
...
```

Group by turn pair so the history reads as a conversation.

---

## §C. Config flow (`/abstract config`)

Re-run the **First-run config flow** (§E) starting from the destination question. Show the current values as defaults so the user can keep them by hitting enter / picking the same option.

After writing the new config, do not produce a recap — just confirm what changed and where the config lives.

---

## §D. Config resolution

Resolution order:

1. `./.claude/abstract.config.json` (per-project — preferred)
2. `~/.claude/abstract.config.json` (global fallback)
3. None found → run §E (first-run config flow)

Config schema (v1):

```json
{
  "version": 1,
  "destination": "<absolute or project-relative path>",
  "writeLessons": true,
  "scrubSecrets": true,
  "historyTokenBudget": 50000
}
```

`destination` may be:
- A path inside the project (`./.claude/sessions`, `./docs/sessions`)
- A sibling path (`../my-notes`)
- An absolute path (e.g. an Obsidian vault under `~/Documents/...`)

When reading the config, expand `~` to `$HOME`. When writing files, `mkdir -p` the `sessions/` and `lessons/` subdirectories under `destination` if missing.

---

## §E. First-run config flow

This runs when no config is found, OR when the user invokes `/abstract config`.

Use the **AskUserQuestion** tool — it renders an arrow-key-navigable list and is the only menu primitive available in Claude Code. Do NOT try to paint a TUI in the terminal.

### E.1 Pick destination

Call `AskUserQuestion` with:

- Question: `Where should Abstract write your session recaps?`
- Header: `Destination`
- Options:
  1. `./.claude/sessions` — Inside this project. Travels with the repo.
  2. `./docs/sessions` — Inside this project's docs folder.
  3. `../<name>` sibling folder — Next to the project (you'll pick the name next).
  4. Custom path — Absolute path (e.g. an Obsidian vault).

The user can also pick "Other" and type a freeform path.

If they picked the sibling option, ask a follow-up question with `AskUserQuestion`:
- Question: `What should the sibling folder be called?`
- Header: `Folder name`
- Options: `notes`, `session-log`, `<project-name>-brain`, custom.

If they picked custom or "Other", accept the freeform path and validate it can be created (`mkdir -p` it).

### E.2 Pick options

Call `AskUserQuestion` once with three questions in the same call (so the user sees them together):

1. **Write a separate lessons file when 2+ lessons emerge?**
   - Yes (recommended) — keeps reusable rules separate from session narrative.
   - No — keep everything in the session file.

2. **Scrub secrets from prompt history?** (only relevant for `/abstract history`)
   - Yes (recommended) — redact API keys, tokens, credentials before writing.
   - No — write prompts verbatim. Only pick this if the project never sees secrets.

3. **Limit history transcripts to ~50k tokens?**
   - Yes (recommended) — summarize older assistant turns when transcripts get huge.
   - No — write everything, however large.

### E.3 Write the config

Default to per-project location (`./.claude/abstract.config.json`). If the project has no `.claude/` directory and the user picked an absolute destination (e.g. a global Obsidian vault), offer a final question:

- Question: `Save this config per-project or globally?`
- Header: `Config scope`
- Options:
  1. Per-project (`./.claude/abstract.config.json`) — recommended if recaps live inside the repo.
  2. Global (`~/.claude/abstract.config.json`) — recommended if recaps go to a shared vault you use across projects.

Write the JSON file with `mkdir -p` first. Confirm the path back to the user, then continue with whatever mode triggered the first-run flow (or end if invoked via `/abstract config`).

---

## §F. Style rules for the recap content

- **Specific over general.** "Changed TenantCard to use UnitBadge instead of raw unit_name" beats "updated tenant display".
- **Honest about mistakes.** Preventing repeats is the whole point. If the assistant suggested the wrong approach and the user corrected it, write that down with the root cause.
- **Actionable lessons.** Every entry in "Lessons for next time" should be copy-pasteable into a project rules file.
- **Short.** A recap is 30-80 lines. If yours is longer, you're narrating instead of summarizing.
- **No em dashes** in user-facing copy — use commas, periods, or parens.

---

## §G. When to use this skill

- At the end of any session with meaningful work.
- After a session with multiple corrections or course changes.
- After establishing a new pattern that should be remembered.
- The user says "recap", "abstract", "write up what we did", "save this session", "log this".
