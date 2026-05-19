# Install

Concrete steps for Claude Code. Adapt paths to your machine; nothing here is
machine-specific.

## 1. Doctrine

Append the contents of `framework/AGENTS.md` to your `CLAUDE.md` (user-level
`~/.claude/CLAUDE.md`, or a project one). Fill the bracketed `[…]` placeholders
— the ladder tiers especially: bend them to your own risk tolerance.

## 2. Memory store

Put the `memory/` folder where your agent can read and write it. Keep
`MEMORY.md` as the index that gets loaded each session, and add a line to your
`CLAUDE.md` telling the agent that's its persistent memory and to read the
index at session start. Create real memory files from `memory/templates/` as
you go — one fact per file, indexed in `MEMORY.md`.

## 3. The loop (session-journal hook)

Pick two paths:

- a **notes/journal** location (your personal store — Obsidian vault, a notes
  folder, anything)
- the **inbox** file inside your memory store (`memory/_INBOX.md`)

Register the hook in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionEnd": [
      { "hooks": [ {
        "type": "command",
        "command": "JF_SESSIONS_DIR='/path/to/notes/Sessions' JF_INBOX_FILE='/path/to/memory/_INBOX.md' bash /path/to/hooks/session-journal/journal.sh 2>/dev/null || true",
        "timeout": 120
      } ] }
    ]
  }
}
```

Optional env: `JF_CLI`, `JF_CHEAP_MODEL`, `JF_USER_NAME` (see the hook README).

Requires `jq`. The first journal entry appears after the *next* session you
start — `SessionEnd` only binds for sessions begun after the hook is
registered.

## 4. Verify

End a session, then check:

- a dated file appeared in your notes Sessions folder, written in your voice
- `memory/_INBOX.md` has a new tagged block

If both happened, the loop is live. From then on: give goals, not scripts, and
correct the pre-flight when it reads you wrong.
