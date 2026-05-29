# Abstract

A portable Claude Code skill for capturing structured end-of-session recaps. Designed so sessions compound into a searchable knowledge base instead of evaporating when the context window closes.

## Install

Drop this folder into one of:

- **Project-scoped:** `<your-project>/.claude/skills/abstract/`
- **User-scoped:** `~/.claude/skills/abstract/` (available across every project)

Claude Code picks up new skills on the next launch. First time you invoke `/abstract`, it walks you through picking a destination folder.

## Usage

| Command | What it does |
|---------|--------------|
| `/abstract` | Writes a structured recap to `<destination>/sessions/YYYY-MM-DD-<slug>.md`. |
| `/abstract history` | Same recap, plus a `## Prompt history` section with your verbatim prompts and one-paragraph summaries of the assistant's responses. Secrets are scrubbed by default. |
| `/abstract config` | Reconfigure destination, lessons-file behavior, secret scrubbing, and token budget. |

The first run on a fresh project triggers a config flow with arrow-key menus (powered by Claude Code's `AskUserQuestion` primitive).

## What gets written

```
<destination>/
  sessions/
    2026-05-29-auth-redirect-fix.md
    2026-05-30-tenant-modal-refactor.md
    ...
  lessons/                      # only if writeLessons: true and 2+ lessons emerged
    2026-05-29-auth-redirect-fix.md
    ...
```

Each session file uses Obsidian-compatible YAML frontmatter (`date`, `category`, `scope`, `tags`) so the recaps are immediately searchable in any Obsidian vault or grep-friendly editor.

## Config

Stored at `./.claude/abstract.config.json` (per-project) or `~/.claude/abstract.config.json` (global). Per-project wins if both exist.

```json
{
  "version": 1,
  "destination": "./.claude/sessions",
  "writeLessons": true,
  "scrubSecrets": true,
  "historyTokenBudget": 50000
}
```

| Field | Meaning |
|-------|---------|
| `destination` | Where `sessions/` and `lessons/` get written. Project-relative, sibling path, or absolute. `~` is expanded. |
| `writeLessons` | If `true`, write a separate `lessons/` file when 2+ reusable lessons emerge. |
| `scrubSecrets` | If `true`, redact API keys, tokens, and credentials from prompt history before writing. |
| `historyTokenBudget` | Soft cap for `/abstract history` output. Older assistant turns get summarized when over budget. |

## How `/abstract history` finds your prompts

Claude Code writes per-session JSONL transcripts to `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl` (where `<encoded-cwd>` is your project path with `/` replaced by `-`). The skill reads the most recently modified `.jsonl` in that directory, extracts user prompts verbatim, summarizes assistant text responses to one paragraph each, and skips tool-call/thinking blocks (with a brief mention like "ran 4 tool calls").

The model running the skill does this parsing — there is no separate parser binary to install.

## Secret scrubbing

For `/abstract history`, by default the skill scans extracted prompts for:

- Anthropic keys (`sk-ant-...`)
- Generic API keys (`sk-...`)
- AWS access keys (`AKIA...`)
- GitHub tokens (`ghp_`, `ghs_`, `github_pat_`)
- Bearer tokens
- Private key blocks (`-----BEGIN ... PRIVATE KEY-----`)
- `password=`, `secret=`, `api_key=` assignments
- Lines from `.env` files

Matches are replaced with `[REDACTED-<kind>]` and a per-kind count is reported. Turn off via config if your project never sees secrets and you want raw prompts.

## Why "abstract"

Like the abstract of a paper — short, structured, written after the work, designed to be useful out of context. Not the conversation, just what mattered about it.

## Limitations

- `AskUserQuestion` menus require interactive Claude Code (CLI or IDE). In headless / scheduled runs the skill will fall back to defaults (per-project destination at `./.claude/sessions`) and log what it chose.
- The JSONL transcript format is internal to Claude Code and may change between versions. If `/abstract history` errors on parsing, check the actual structure with `head -3 <transcript>.jsonl | jq .` and either update the skill's jq filter or file an issue.
- Token-budget estimation is rough (4 chars/token); long sessions may still exceed the model's working memory if `historyTokenBudget` is too high.

## License

Do whatever you want with it.
