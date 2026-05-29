---
name: abstract
description: Write a structured end-of-session recap to a markdown note. Captures what changed, why, decisions made, mistakes, and lessons learned so sessions compound into a searchable knowledge base. For prompt-history dumps use /abstract-history, to reconfigure use /abstract-config, to generate rules from a session use /abstract-rule.
---

# Abstract — Standard Recap

Write a structured session recap to `<destination>/sessions/YYYY-MM-DD-<slug>.md`.

## Step 1: Resolve config

Check for a config file in this order:

1. `./.claude/abstract.config.json` (per-project)
2. `~/.claude/abstract.config.json` (global)

If **neither exists**, the user hasn't run first-run setup. Tell them:

> No Abstract config found. Run `/abstract-config` first to pick where recaps should be written, then re-run `/abstract`.

Then stop. Do NOT proceed.

If a config exists, read its `destination` field. Expand `~` to `$HOME`. Make sure `<destination>/sessions/` exists (`mkdir -p`).

## Step 2: Gather context

Run these in parallel:

```bash
git diff --stat HEAD~5..HEAD 2>/dev/null || git diff --stat
git log --oneline -20 --no-merges
git status --short
git branch --show-current
```

Review the conversation so far: what the user asked for, what was built, what went wrong, what was corrected.

## Step 3: Classify the session

Pick one primary category. Use `other` if nothing fits.

- `feature` — new capability, page, or component
- `fix` — bug fix or correction
- `refactor` — restructuring without behavior change
- `migration` — data layer, API, infra, or framework migration
- `design` — UI/UX, design system, styling
- `config` — tooling, CI, settings, environment
- `docs` — documentation only
- `research` — exploration with no shipped change
- `other`

## Step 4: Choose a slug

Short kebab-case description of the session (e.g. `auth-redirect-fix`, `tenant-modal-refactor`). Under 40 chars. If a file already exists at the target path, append `-2`, `-3`, etc.

## Step 4.5: Tag domains (only if config.domains is non-empty)

If `config.domains` exists and is non-empty, the user has defined a taxonomy for `/abstract-compile`. Show them a multi-select prompt so this session can land in the right per-domain playbooks.

Use **AskUserQuestion** with `multiSelect: true`:

- Question: `Which domains does this session relate to? (Used by /abstract-compile.)`
- Header: `Domains`
- Options: one per domain from `config.domains`. Add a final option `None / skip` so the user can opt out.

If the user picks `None / skip` (or doesn't pick anything), set `domains: []` in the frontmatter — the session is untagged and won't show up in any playbook.

If `config.domains` is missing or empty, skip this step silently. The user hasn't set up a taxonomy yet; recap proceeds untagged.

## Step 5: Write the recap

Target path:
```
<destination>/sessions/YYYY-MM-DD-<slug>.md
```

Use this template exactly:

```markdown
---
date: YYYY-MM-DD
category: <one of step 3>
scope: [list of files, components, or systems touched]
tags: [domain tags — e.g. api, auth, typography]
domains: [list from step 4.5, or empty if untagged]
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
- What went wrong during the session.
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

## Step 6: Optional lessons file

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

## Step 7: Confirm

Tell the user:
- Path of the file(s) written
- How many lessons captured
- Suggest `/abstract-rule` if the session is complex enough to warrant project rules

## Style rules

- **Specific over general.** "Changed TenantCard to use UnitBadge instead of raw unit_name" beats "updated tenant display".
- **Honest about mistakes.** Preventing repeats is the whole point.
- **Actionable lessons.** Every entry in "Lessons for next time" should be copy-pasteable into a project rules file.
- **Short.** A recap is 30-80 lines. Longer means narrating instead of summarizing.
- **No em dashes** in user-facing copy — use commas, periods, or parens.
