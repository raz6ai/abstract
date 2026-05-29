---
name: abstract-rule
description: Read an existing session recap and turn its lessons, patterns, and decisions into reusable project rule files. For each candidate, you choose - let Claude write the full rule, get a stub to fill in yourself, or skip. Every rule links back to the source session. RECOMMENDED ONLY FOR COMPLEX OR MULTI-DECISION SESSIONS - simple fixes don't need rules.
---

# Abstract Rule — Turn a Session into Project Rules

Read a session recap, extract concrete rule candidates, and write them to the project rules folder. Each rule file references the source session so future readers can dig into the context.

## When to use this

**Use** for sessions where the assistant established new patterns, reversed direction multiple times, or made non-obvious architectural decisions that should bind future work.

**Don't use** for routine fixes, doc updates, or sessions where the recap's "Lessons for next time" section is empty or trivial. Rules are forever — keep the signal-to-noise ratio high.

Before doing any work, tell the user this skill is best for complex sessions and ask them to confirm if the session looks light. If they confirm anyway, proceed.

## Step 1: Resolve config

Check for config in this order:
1. `./.claude/abstract.config.json`
2. `~/.claude/abstract.config.json`

If neither exists:

> No Abstract config found. Run `/abstract-config` first, then re-run `/abstract-rule`.

Stop.

Read `destination`. Read `rulesDestination` if present. If `rulesDestination` is missing, ask now:

Question: `Where should /abstract-rule write project rules?`
Header: `Rules destination`
Options:
1. `./.claude/rules` — Standard Claude Code rules dir. (Recommended)
2. `./docs/rules` — Inside docs.
3. Custom path.

Persist the choice to the config file.

## Step 2: Pick a session

List session files:

```bash
ls -t "<destination>/sessions/"*.md 2>/dev/null | head -10
```

If no session files exist:

> No sessions found at `<destination>/sessions/`. Run `/abstract` first to capture a session, then re-run `/abstract-rule`.

Stop.

Default to the most recent file. If multiple exist, use AskUserQuestion:

Question: `Which session do you want to extract rules from?`
Header: `Session`
Options:
1. `<basename of most recent>` (Recommended)
2. `<basename of second most recent>`
3. `<basename of third most recent>`
4. Other — enter a path.

Up to 4 options shown; if there are more, "Other" lets the user paste a path.

## Step 3: Scan for rule candidates

Read the session file. Extract entries from these sections, in priority order:

1. **Lessons for next time** — every bullet here is a high-priority candidate. Already in rule format (`**Rule:** ... **Why:** ...`).
2. **Patterns established** — each bullet is a medium-priority candidate; needs to be reshaped into a rule.
3. **Decisions made** — extract only those phrased prescriptively ("Always use X", "Never do Y"). Skip narrative decisions.
4. **Mistakes and corrections** — each mistake is a candidate "don't do X" rule. Skip if it was a one-off slip with no general lesson.

For each candidate, prepare:
- A short kebab-case slug (from the rule's subject, capped at 40 chars)
- A draft title
- The source bullet (verbatim)
- A suggested category (matching the session's `category` frontmatter)

If no candidates emerge, tell the user the session is too light for rules and exit gracefully.

## Step 4: Present each candidate

Loop over candidates. For each, use AskUserQuestion:

Question: `Rule candidate: "<draft title>". What do you want to do?`
Header: `Rule N of M`
Options:
1. **Auto-write** — Claude drafts the full rule file using the session's context.
2. **Stub only** — write a skeleton (frontmatter, title, source link, empty section headers) for you to fill in later.
3. **Skip** — don't write this one.

Show the source bullet under the question (in the question body) so the user knows what they're voting on.

## Step 5: Write rules

For each accepted candidate, write to:
```
<rulesDestination>/<slug>.md
```

If a file already exists at the path, append `-2`, `-3`, etc.

### Auto-write template

```markdown
---
date: YYYY-MM-DD
source_session: <relative path from rulesDestination to the session file>
category: <session category>
tags: [domain tags from the session frontmatter]
---

# <Rule title>

> Source: [<session basename>](<relative source path>)

## Rule
<the actionable rule, phrased as an imperative — "Always X", "Never Y", "When Z, do W">

## Why
<what goes wrong without this rule — pull context from the session's "Mistakes" or "Why" sections>

## How to apply
<when this rule fires — file paths, situations, code patterns where it kicks in>

## Example
<concrete before/after, drawn from the session if possible>
```

### Stub template

```markdown
---
date: YYYY-MM-DD
source_session: <relative path>
category: <session category>
tags: []
---

# <Draft rule title>

> Source: [<session basename>](<relative source path>)

## Rule
<!-- TODO -->

## Why
<!-- Source bullet from the session: -->
<!-- > <verbatim source bullet> -->

## How to apply
<!-- TODO -->

## Example
<!-- TODO -->
```

The stub includes the verbatim source bullet as a comment so the user has the original context when they fill it in.

## Step 6: Confirm

Tell the user:
- How many candidates were found, accepted, stubbed, skipped
- Paths of files written
- Any rule files that already existed (and what suffix was used)
- Suggest reviewing the rules and possibly moving high-impact ones into the project's auto-loaded rules directory if `rulesDestination` differs from where the project loads rules at runtime

## Style rules

- Rules are imperative: "Always X" / "Never Y" / "When Z, do W".
- Every rule references its source session — don't write rules without provenance.
- One rule per file. Don't bundle multiple lessons into one rule doc.
- Skip rules that are too project-specific to ever apply elsewhere. The whole point is reusability.
- No em dashes in user-facing copy — use commas, periods, or parens.
