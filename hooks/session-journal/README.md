# session-journal hook

Runs when an agent session ends. Turns the transcript into two things:

- a **journal entry in your voice** → your personal notes (your complete record)
- **tagged candidate facts** → the agent memory inbox (reviewed before they're trusted)

This is the mechanism that *closes the loop* — nothing learned in a session is
lost when it ends.

## Wire it up

Point your agent's `SessionEnd` hook at the script. For Claude Code, in
`settings.json`:

```json
{
  "hooks": {
    "SessionEnd": [
      { "hooks": [ {
        "type": "command",
        "command": "bash /ABSOLUTE/PATH/hooks/session-journal/journal.sh 2>/dev/null || true",
        "timeout": 120
      } ] }
    ]
  }
}
```

Set the config via environment (or edit the defaults at the top of the script):

| Var | What it is |
|---|---|
| `JF_SESSIONS_DIR` | folder for daily journal files (your notes store) |
| `JF_INBOX_FILE` | the memory inbox file deltas append to |
| `JF_CLI` | the agent CLI invoked headlessly (default `claude`) |
| `JF_CHEAP_MODEL` | the cheap/fast model used for extraction (default `haiku`) |
| `JF_USER_NAME` | whose first-person voice the journal uses (default `I`) |

## Design notes

- **One model call, two outputs.** Sentinel-delimited blocks, split in shell.
  Half the cost of two calls.
- **Recursion guard.** The hook spawns the agent CLI, which would re-fire
  `SessionEnd`; the child runs with `JF_HOOK=1` and the script no-ops on it.
- **Fails safe.** Never blocks session exit; diagnostics in `journal.log`.
- **Cheap model proposes, capable model disposes.** The hook only *stages*
  facts. The quality gate is the review at the next pre-flight — that's what
  keeps memory from becoming a noise dump.
- **First run caveat.** `SessionEnd` only fires for sessions that *started*
  after the hook was registered. The first journal appears after the next
  session you start, not the one you're in when you install it.

> Requires `jq`.
