#!/bin/bash
# SessionEnd hook — closes the write-back loop.
#
# One cheap-model call produces TWO outputs from the session transcript:
#   1. JOURNAL  -> a first-person journal entry in the USER's voice,
#                  appended to a daily file in their personal notes store.
#   2. DELTAS   -> tagged candidate facts (STATE/DECISION/PERSONA/THREAD),
#                  appended to the agent memory inbox for later review.
#
# The journal is the user's complete record. The deltas are NOT trusted
# memory — the capable model reviews and merges them at the next session's
# pre-flight (see framework/AGENTS.md). Cheap model proposes; capable model
# disposes.
#
# Configure via these env vars (or edit the defaults):
#   JF_SESSIONS_DIR  - dir for daily journal files (the user's notes store)
#   JF_INBOX_FILE    - the memory inbox file to append deltas to
#   JF_CLI           - the agent CLI invoked headlessly (default: claude)
#   JF_CHEAP_MODEL   - the cheap/fast model name (default: haiku)
#   JF_USER_NAME     - whose first-person voice the journal is in (default: I)
#
# Recursion guard: this hook spawns the agent CLI, whose own session would
# fire SessionEnd again. JF_HOOK=1 is exported for that child so it no-ops.
set -euo pipefail

[ "${JF_HOOK:-}" = "1" ] && exit 0

SESSIONS_DIR="${JF_SESSIONS_DIR:?set JF_SESSIONS_DIR to your notes Sessions dir}"
INBOX_FILE="${JF_INBOX_FILE:?set JF_INBOX_FILE to your memory inbox path}"
CLI="${JF_CLI:-claude}"
CHEAP_MODEL="${JF_CHEAP_MODEL:-haiku}"
USER_NAME="${JF_USER_NAME:-I}"
LOG="$(dirname "$0")/journal.log"

log() { echo "$(date '+%F %T') $*" >> "$LOG" 2>/dev/null || true; }

# --- read hook stdin -------------------------------------------------------
INPUT="$(cat)"
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
SID8="${SID:0:8}"

[ -z "$TRANSCRIPT" ] || [ ! -s "$TRANSCRIPT" ] && { log "no transcript ($SID8)"; exit 0; }

# --- extract the conversation (user + assistant text only) -----------------
CONVO="$(jq -rs '
  [ .[]
    | select(.type=="user" or .type=="assistant")
    | (.message.role // .type) as $r
    | (.message.content) as $c
    | if ($c|type)=="string" then "[\($r)] \($c)"
      elif ($c|type)=="array" then
        ([ $c[] | select(.type=="text") | .text ] | join("\n")) as $t
        | if ($t|length)>0 then "[\($r)] \($t)" else empty end
      else empty end
  ] | join("\n\n")
' "$TRANSCRIPT" 2>/dev/null | tail -c 60000 || true)"

if [ "${#CONVO}" -lt 200 ]; then log "too short ($SID8, ${#CONVO}b)"; exit 0; fi

# --- one cheap call, two outputs ------------------------------------------
PROMPT="You produce TWO blocks from the session transcript below, separated by the exact sentinel lines shown. Output nothing outside the blocks.

<<<JOURNAL>>>
A private journal entry in the FIRST-PERSON voice of ${USER_NAME}, the user (NOT the assistant) — the user's own memory of this session. Cover, only where it applies: what I set out to do and what got done; specific instructions/preferences/corrections/opinions I gave; decisions made and why; anything still open. Past tense, my voice. Tight markdown bullets, no headings/preamble/sign-off. Do not invent detail. If nothing substantive, put exactly SKIP in this block.

<<<DELTAS>>>
Durable signal for the agent's curated memory — terse, only categories with REAL new content. Each line prefixed with its tag:
- STATE: a project's status changed (what is now true that wasn't)
- DECISION: a decision + reasoning, if it constrains future work
- PERSONA: a signal about how the user decides/prefers/reacts (risk posture, trust tells, proposal style)
- THREAD: an open loop opened or closed
This is a candidate list for review, not final memory — be conservative, skip the trivial. If nothing durable, put exactly NONE in this block.

Transcript:

$CONVO"

RAW="$(JF_HOOK=1 "$CLI" -p "$PROMPT" --model "$CHEAP_MODEL" 2>>"$LOG" || true)"

ENTRY="$(printf '%s' "$RAW"  | awk '/^<<<JOURNAL>>>/{f=1;next} /^<<<DELTAS>>>/{f=0} f' | sed -e 's/[[:space:]]*$//' -e '/./,$!d')"
DELTAS="$(printf '%s' "$RAW" | awk '/^<<<DELTAS>>>/{f=1;next} f'                       | sed -e 's/[[:space:]]*$//' -e '/./,$!d')"

if [ -z "$ENTRY" ] || [ "$(printf '%s' "$ENTRY" | tr -d '[:space:]')" = "SKIP" ]; then
  log "skip/empty entry ($SID8)"; exit 0
fi

# --- append journal to today's notes file ---------------------------------
mkdir -p "$SESSIONS_DIR"
DAY="$(date '+%F')"
FILE="$SESSIONS_DIR/$DAY.md"
[ -f "$FILE" ] || printf '# Sessions — %s\n' "$DAY" > "$FILE"
{
  printf '\n## %s · session %s\n\n' "$(date '+%H:%M')" "$SID8"
  printf '%s\n' "$ENTRY"
} >> "$FILE"
log "wrote entry ($SID8) -> $FILE"

# --- route deltas to the memory inbox (capable model reviews later) -------
if [ -n "$DELTAS" ] && [ "$(printf '%s' "$DELTAS" | tr -d '[:space:]')" != "NONE" ]; then
  mkdir -p "$(dirname "$INBOX_FILE")"
  [ -f "$INBOX_FILE" ] || printf '# Memory inbox — unprocessed session deltas\n\nStaging, not curated memory. Reviewed and drained at the next pre-flight.\n' > "$INBOX_FILE"
  {
    printf '\n## %s · session %s\n\n' "$(date '+%F %H:%M')" "$SID8"
    printf '%s\n' "$DELTAS"
  } >> "$INBOX_FILE"
  log "wrote deltas ($SID8) -> $INBOX_FILE"
fi
exit 0
