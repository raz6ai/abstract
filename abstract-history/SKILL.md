---
name: abstract-history
description: Write a session recap AND append the full prompt history (user prompts verbatim, assistant turns summarized) by reading Claude Code's JSONL transcript file. Secrets are scrubbed by default. Heavier than /abstract — only use when you need a full conversational record.
---

# Abstract History — Recap with Prompt History

Do everything `/abstract` does, then append a `## Prompt history` section with the actual conversation pulled from Claude Code's session transcript.

## Step 1: Resolve config

Check for a config file in this order:

1. `./.claude/abstract.config.json` (per-project)
2. `~/.claude/abstract.config.json` (global)

If neither exists, tell the user:

> No Abstract config found. Run `/abstract-config` first to pick where recaps should be written, then re-run `/abstract-history`.

Then stop.

Read `destination`, `scrubSecrets` (default `true`), and `historyTokenBudget` (default `50000`).

## Step 2: Locate the transcript

Claude Code writes per-session JSONL transcripts to:
```
~/.claude/projects/<encoded-cwd>/<session-id>.jsonl
```

Where `<encoded-cwd>` is the current working directory with `/` replaced by `-`.

```bash
ENCODED_CWD=$(pwd | sed 's|/|-|g')
TRANSCRIPT_DIR="$HOME/.claude/projects/$ENCODED_CWD"
LATEST=$(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1)
echo "$LATEST"
wc -l "$LATEST" 2>/dev/null
```

If `$LATEST` is empty, tell the user no transcript was found at `$TRANSCRIPT_DIR` and fall back to the standard `/abstract` flow (write the recap, skip the history section, mention what was missing).

## Step 3: Write the standard recap

Run steps 2-6 from `/abstract` (gather context → classify → choose slug → write the file → optional lessons file). Use the same `<destination>/sessions/YYYY-MM-DD-<slug>.md` path.

## Step 4: Parse transcript turns

Each line of the JSONL is one event. Extract:
- **User turns:** `.type == "user"` with `.message.content` as string or array containing `{type:"text", text:...}` blocks.
- **Assistant turns:** `.type == "assistant"` with `.message.content` as array. Extract `{type:"text", text:...}` blocks. Count but don't include `{type:"tool_use"}` and `{type:"thinking"}` blocks — mention them as "ran N tool calls".

```bash
jq -c 'select(.type=="user" or .type=="assistant") | {type, content: (.message.content | if type=="string" then . else (map(select(.type=="text") | .text) | join("\n")) end), tool_count: (.message.content | if type=="array" then (map(select(.type=="tool_use")) | length) else 0 end)}' "$LATEST"
```

If the schema differs from what you expect (Claude Code version variance), inspect the first few lines with `head -3 "$LATEST" | jq .` and adapt the filter.

## Step 5: Secret scrub

If `config.scrubSecrets` is `true` (the default), redact matches in extracted text. Replace each with `[REDACTED-<kind>]` and track counts per kind.

| Pattern | Kind |
|---------|------|
| `sk-ant-[A-Za-z0-9_-]{20,}` | anthropic-key |
| `sk-[A-Za-z0-9]{20,}` | api-key |
| `AKIA[0-9A-Z]{16}` | aws-key |
| `ghp_[A-Za-z0-9]{36}`, `ghs_[A-Za-z0-9]{36}`, `github_pat_[A-Za-z0-9_]{82}` | github-token |
| `Bearer\s+[A-Za-z0-9._-]{20,}` | bearer-token |
| `-----BEGIN [A-Z ]*PRIVATE KEY-----` | private-key |
| `(password\|passwd\|secret\|api[_-]?key)\s*[:=]\s*['"\`]?[^\s'"\`]{6,}` (case-insensitive) | credential |
| Any line that visibly came from a `.env` file in the session | env-value |

After scrubbing, save the per-kind counts to report later.

If `config.scrubSecrets` is `false`, skip and warn the user in the final report.

## Step 6: Token budget

If `config.historyTokenBudget` is set (default 50000), estimate token count (rough: 4 chars per token).

If over budget:
1. Keep all user prompts verbatim.
2. Summarize assistant turns aggressively — replace long responses with one sentence: `Assistant: <one-sentence summary>. <N> tool calls.`
3. If still over, drop the oldest tool-call-only assistant turns first.

Report what was summarized.

## Step 7: Append the history section

Append to the session file written in step 3:

```markdown

## Prompt history

> Transcript: <basename of $LATEST>
> Turns: <user_count> user, <assistant_count> assistant
> Redactions: <total N> (<kind>: <count>, ...) or "none"
> Token budget: <est tokens> / <budget> (<within / summarized>)

### Turn 1 — User
<verbatim user prompt, after redaction>

### Turn 1 — Assistant
<one-paragraph summary of what the assistant did and said; mention tool calls if any>

### Turn 2 — User
...
```

Group by turn pair so the history reads as a conversation.

## Step 8: Confirm

Tell the user:
- Path of the file written
- Total turns captured
- Redaction summary
- Whether anything was summarized due to budget

## When to use this skill

- Sessions you want a full conversational record of (debugging walkthrough, decision-heavy session, hand-off to another person).
- Avoid for routine work — `/abstract` is lighter and produces a cleaner artifact for grep/Obsidian search.
