---
name: abstract-compile
description: Read all session recaps tagged with domains (ui, backend, etc.), synthesize per-domain playbook skills at .claude/skills/abs-<domain>/. Each playbook accumulates mistakes to avoid, validated patterns, rules, and decisions across sessions, so /abs-ui or /abs-backend gives Claude domain-specific wisdom on demand. Run after a batch of new tagged sessions land, or whenever you want the playbooks refreshed.
---

# Abstract Compile — Synthesize per-domain playbooks

Read every tagged session in `<destination>/sessions/`, group by domain, and write a playbook skill per domain at `.claude/skills/abs-<domain>/SKILL.md`. Each playbook is a static reference doc that loads into Claude's context when the user invokes `/abs-<domain>`.

## Step 1: Resolve config

Read config from `./.claude/abstract.config.json` (preferred) or `~/.claude/abstract.config.json`. If neither exists:

> No Abstract config found. Run `/abstract-config` first, then re-run `/abstract-compile`.

Stop.

Read `destination` (where sessions live) and `domains` (the taxonomy — may be missing or empty on first run).

## Step 2: Bootstrap domain taxonomy if empty

If `config.domains` is missing or empty, the user hasn't defined a taxonomy yet. Do this:

1. Scan existing session files for any pre-existing `domains:` field in frontmatter (in case they were tagged manually). Collect the union.
2. If anything was found, propose those as a starting taxonomy via **AskUserQuestion** (multiSelect):
   - Question: `Found these domains tagged in existing sessions. Confirm which to use as your taxonomy.`
   - Header: `Bootstrap`
   - Options: one per discovered domain.
3. If nothing was found, propose common defaults via AskUserQuestion (multiSelect):
   - Question: `No domains defined yet. Pick the ones that fit this project.`
   - Header: `Bootstrap`
   - Options: `ui`, `backend`, `auth`, `data`, `infra` (plus Other for custom).
4. Persist the chosen list to `config.domains` and write the config file.

After bootstrap, tell the user: "Tag future sessions during `/abstract` to populate these playbooks. Run `/abstract-compile` again after a few sessions land."

If at this point no sessions exist OR no sessions are tagged with any domain, stop with the message above (nothing to compile yet).

## Step 3: Gather tagged sessions per domain

```bash
SESS_DIR="<destination>/sessions"
ls "$SESS_DIR"/*.md 2>/dev/null
```

For each session file, read its YAML frontmatter and extract the `domains:` field (an array, possibly empty or missing). Build a map:

```
domain → [list of session file paths]
```

Skip sessions that have no `domains` field or an empty list (untagged — they don't go in any playbook).

If, after this pass, NO sessions are tagged at all, tell the user:

> No sessions are tagged yet. Tag sessions during `/abstract` (the prompt shows your domain taxonomy) and re-run `/abstract-compile`.

Stop.

## Step 4: Confirm scope

Show the user how many sessions map to each domain via AskUserQuestion (multiSelect):

- Question: `Which domain playbooks do you want to (re)compile?`
- Header: `Domains`
- Options: one per domain, label includes session count: `ui (12 sessions)`, `backend (7 sessions)`, etc.
- Include an "All of them" option as the first choice for convenience.

For each chosen domain, proceed to step 5.

## Step 5: Synthesize a playbook per domain

For each chosen domain, read every tagged session file. For each session, pull these sections (using markdown heading boundaries):

- `## Mistakes and corrections`
- `## Patterns established`
- `## Lessons for next time`
- `## Decisions made`

Synthesize them into a single playbook with this structure:

```markdown
---
name: abs-<domain>
description: <ONE LINE: synthesized summary of the domain — what kinds of mistakes are typical, what patterns are validated, what rules apply>. Compiled from <N> session abstractions. Invoke to load <domain>-specific wisdom into Claude's context.
---

# <Domain> Playbook

> Compiled <YYYY-MM-DD> from <N> session abstraction(s) tagged `<domain>`.

## Mistakes to avoid

- <synthesized mistake>. Root cause: <root cause>. _Source: [<session-basename>](<relative path to session>)_
- ...

## Validated patterns

- <pattern>. _Source: [<session-basename>](<rel path>)_
- ...

## Rules

- **Rule:** <imperative rule>. **Why:** <consequence without it>. _Source: [<session-basename>](<rel path>)_
- ...

## Decision log

- <date> — <decision summary>. _Source: [<session-basename>](<rel path>)_
- ...

## Sources

- <YYYY-MM-DD> — [<slug>](<relative path to session>)
- ...
```

### Synthesis rules

- **Deduplicate.** If the same lesson appears in 3 sessions, write it once and list all 3 sources.
- **Merge near-duplicates.** "Always use `<Badge variant=neutral>`" and "Don't use `variant=default` for chips" are the same rule — merge.
- **Skip noise.** Lessons that are too project-specific or one-offs (typos, environment-only) get dropped. Better an empty section than a noisy one.
- **Keep imperatives short.** Rules use imperative voice: "Always X", "Never Y", "When Z, do W".
- **Provenance is mandatory.** Every entry in the playbook links back to at least one source session. No orphan entries.
- **Description is one line.** The skill description shows up in autocomplete; keep it actionable and specific.

### Token budget

If the chosen domain has more than ~30 sessions, the raw input may exceed comfortable working memory. In that case:
1. Process sessions in batches of 20.
2. Maintain a running playbook draft; after each batch, merge new entries into the existing draft (dedup as you go).
3. Report progress: `Batch 1/3 processed: 18 unique mistakes, 22 patterns, 31 rules so far.`

## Step 6: Write the playbook files

For each compiled domain, write to:
```
./.claude/skills/abs-<domain>/SKILL.md
```

If the file already exists, the existing one is overwritten (compile is always a full rebuild — that's the design call). Tell the user before doing this if the file size would shrink by more than 50% (suggests something went wrong).

## Step 7: Confirm

Tell the user, for each compiled domain:
- Path written
- Session count
- Counts of mistakes / patterns / rules / decisions captured
- Remind them to restart Claude Code so the new `abs-<domain>` skills register in autocomplete.

Suggest: "Type `/abs-` after the restart to see your domain playbooks alongside the abstract family."

## When NOT to use

- After a single session that's not particularly important — overhead isn't worth it.
- When you've made manual edits to existing `abs-<domain>/SKILL.md` files you want preserved (compile is destructive).
- Before you've defined a taxonomy and tagged at least a few sessions — run `/abstract-config` and write some recaps first.
