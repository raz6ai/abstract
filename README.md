# Abstract

A family of four Claude Code skills for capturing structured end-of-session recaps and turning them into reusable project rules. Designed so sessions compound into a searchable knowledge base instead of evaporating when the context window closes.

## The six skills

| Skill | Purpose |
|-------|---------|
| `/abstract` | Write a structured session recap to `<destination>/sessions/YYYY-MM-DD-<slug>.md`. If a domain taxonomy is configured, prompts to multi-tag the session. |
| `/abstract-history` | Same as `/abstract`, plus appends the full prompt history (user prompts verbatim, assistant turns summarized) read from Claude Code's JSONL transcript file. Secrets scrubbed by default. |
| `/abstract-config` | First-run setup or reconfiguration. Walks through arrow-key menus to pick destination, lessons-file behavior, secret scrubbing, token budget, rules destination, and domain taxonomy. |
| `/abstract-rule` | Read an existing session, scan it for rule candidates, and for each one let you pick "Claude writes it", "stub I'll fill in", or "skip". Every rule references the source session. Recommended only for complex sessions. |
| `/abstract-compile` | Read every tagged session, group by domain, synthesize per-domain playbook skills (`abs-ui`, `abs-backend`, etc.) at `.claude/skills/abs-<domain>/SKILL.md`. Each playbook gives Claude domain-specific wisdom on demand. |
| `/abstract-update` | Pull the latest version of the skills from GitHub and reinstall (user-scoped, project-scoped, or both). Restart Claude Code after running. |

When you type `/abs` in Claude Code, all six show in the autocomplete dropdown. After running `/abstract-compile`, your generated playbooks (`/abs-ui`, `/abs-backend`, etc.) join them.

## Install

```bash
git clone https://github.com/raz6ai/abstract /tmp/abstract && /tmp/abstract/install.sh && rm -rf /tmp/abstract
```

That copies the four skills into `~/.claude/skills/` (user-scoped, available in every project). To install into a project's `.claude/skills/` instead:

```bash
git clone https://github.com/raz6ai/abstract /tmp/abstract
ABSTRACT_INSTALL_DIR=./.claude/skills /tmp/abstract/install.sh
rm -rf /tmp/abstract
```

Or copy by hand:

```bash
git clone https://github.com/raz6ai/abstract
cp -r abstract/abstract abstract/abstract-history abstract/abstract-config abstract/abstract-rule ~/.claude/skills/
```

Restart Claude Code after installing. Then run `/abstract-config` once to pick where recaps should go.

## To update

Once installed, the easiest way to update is to invoke the skill itself:

```
/abstract-update
```

It clones the latest, detects whether you're on user-scoped or project-scoped (or both), and reinstalls. Restart Claude Code after.

If `/abstract-update` isn't available yet (you installed before it was added), re-run the install command:

```bash
git clone https://github.com/raz6ai/abstract /tmp/abstract && /tmp/abstract/install.sh && rm -rf /tmp/abstract
```

## Typical workflow

1. `/abstract-config` (once per project or globally) — pick destination, options, and optionally define a domain taxonomy (`ui`, `backend`, etc.).
2. End of a work session: `/abstract` — write a recap. If a taxonomy is set, multi-tag the session by domain.
3. If the session was unusually complex: `/abstract-rule` — extract reusable rules.
4. If you want a full conversational record: `/abstract-history` — recap plus prompt history.
5. After a batch of tagged sessions land: `/abstract-compile` — synthesize per-domain playbooks (`/abs-ui`, `/abs-backend`, etc.) so Claude can load domain-specific wisdom on demand in future sessions.

## What gets written

```
<destination>/
  sessions/
    2026-05-29-auth-redirect-fix.md
    2026-05-30-tenant-modal-refactor.md
  lessons/                                  # only if writeLessons: true and 2+ lessons emerged
    2026-05-29-auth-redirect-fix.md

<rulesDestination>/                         # written by /abstract-rule
  no-double-unwrap-api-envelope.md
  redirect-locked-routes-via-guard.md
```

Each session file uses Obsidian-compatible YAML frontmatter (`date`, `category`, `scope`, `tags`) so the recaps are immediately searchable in any Obsidian vault or grep-friendly editor.

## Config

Stored at `./.claude/abstract.config.json` (per-project) or `~/.claude/abstract.config.json` (global). Per-project wins if both exist.

```json
{
  "version": 1,
  "destination": "./.claude/sessions",
  "rulesDestination": "./.claude/rules",
  "domains": ["ui", "backend", "auth"],
  "writeLessons": true,
  "scrubSecrets": true,
  "historyTokenBudget": 50000
}
```

| Field | Meaning |
|-------|---------|
| `destination` | Where `sessions/` and `lessons/` get written. Project-relative, sibling path, or absolute. `~` is expanded. |
| `rulesDestination` | Where `/abstract-rule` writes rule files. Defaults to `./.claude/rules`. |
| `domains` | Optional taxonomy used by `/abstract` (tag prompt) and `/abstract-compile` (playbook grouping). Omit or set to `[]` to disable tagging entirely. |
| `writeLessons` | If `true`, write a separate `lessons/` file when 2+ reusable lessons emerge. |
| `scrubSecrets` | If `true`, redact API keys, tokens, and credentials from prompt history before writing. |
| `historyTokenBudget` | Soft cap for `/abstract-history` output. Older assistant turns get summarized when over budget. |

## How `/abstract-history` finds your prompts

Claude Code writes per-session JSONL transcripts to `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl` (where `<encoded-cwd>` is your project path with `/` replaced by `-`). The skill reads the most recently modified `.jsonl` in that directory, extracts user prompts verbatim, summarizes assistant text responses, and skips tool-call/thinking blocks (with a brief mention like "ran 4 tool calls").

The model running the skill does this parsing — there's no separate parser binary to install.

## Secret scrubbing

For `/abstract-history`, by default the skill scans extracted prompts for:

- Anthropic keys (`sk-ant-...`)
- Generic API keys (`sk-...`)
- AWS access keys (`AKIA...`)
- GitHub tokens (`ghp_`, `ghs_`, `github_pat_`)
- Bearer tokens
- Private key blocks
- `password=`, `secret=`, `api_key=` assignments
- Lines that came from a `.env` file in the session

Matches are replaced with `[REDACTED-<kind>]` and a per-kind count is reported. Turn off via config if your project never sees secrets.

## Why six skills instead of one?

Claude Code's autocomplete only shows top-level skill names — args you pass to a skill (`/abstract history`) aren't discoverable in the dropdown. Splitting into six skills means typing `/abs` surfaces all of them, so users find the modes they need without reading the README first.

The compiled `abs-<domain>` playbooks follow the same convention: once you run `/abstract-compile`, your `/abs-ui`, `/abs-backend`, etc. also show up in autocomplete alongside the abstract family.

## Limitations

- `AskUserQuestion` menus require interactive Claude Code (CLI or IDE). In headless / scheduled runs the skills fall back to defaults and log what they chose.
- The JSONL transcript format is internal to Claude Code and may change between versions. If `/abstract-history` errors on parsing, check the structure with `head -3 <transcript>.jsonl | jq .` and either update the skill's jq filter or open an issue.
- Token-budget estimation is rough (4 chars/token); long sessions may still exceed the model's working memory if `historyTokenBudget` is too high.
- Menu chrome (the `AskUserQuestion` picker UI) isn't styleable per-skill. It uses Claude Code's theme. Custom colors would have to come from a Claude Code theme update.

## License

Do whatever you want with it.
