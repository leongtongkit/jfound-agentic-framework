# Architecture & rationale

Why each piece exists, and the reasoning it's built on. If you only read one
doc, read the README; this is the deeper "why".

## The problem it solves

Most people use an AI agent as a stateless tool: explain the context, get a
result, repeat — re-explaining the same context every time, and losing every
hard-won decision the moment the session closes. The agent never gets to know
*you* or *your work*. It cannot improve.

This framework makes the agent **compound**: you give a goal, it self-drives
using a model of you and a record of the past, and every session leaves both
sharper than it found them.

## The two stores, and why two

| Store | Authority on | Voice |
|---|---|---|
| Personal notes | intent, priority, preference | the user's |
| Agent memory | technical state, what was tried | the agent's |

They are deliberately separate. The user's notes are their current head — what
they *want*. The agent memory is operational truth — what *is*. Keeping them
apart means neither overwrites the other, and the split gives a clean conflict
rule: **on disagreement, personal notes win on intent; agent memory wins on
technical fact.** Cross-link; never duplicate.

## Why a review gate instead of auto-writing memory

The cheapest moment to extract durable signal is at session end, while context
is hot — so a cheap, fast model does that extraction. But a cheap model writing
straight into trusted memory would silt it up with noise. So extracted facts
land in an **inbox** (staging), and the capable model reviews and merges them
at the next session's pre-flight. **Cheap model proposes; capable model
disposes.** The review *is* the quality gate.

## Why the pre-flight manifest

The most expensive failure mode in autonomous work is a silent wrong
assumption that runs to completion. The fix is cheap: before acting, the agent
states in a few lines what it's driving from and what "done" means. The user
can veto for the cost of reading five lines instead of reviewing a finished
mistake. This is also where the agent surfaces its model of the user — so a
wrong read of *you* gets corrected before it's acted on. That correction loop
is what makes the user-model converge on reality instead of drifting.

## Why the autonomy ladder

Round-trips kill speed. Most "should I?" pauses are wasted on work that was
always fine to just do. The ladder makes that explicit once, so the agent acts
freely where it's safe and stops hard where it isn't — and the user isn't a
bottleneck on their own tooling.

## On multi-agent fan-out (the honest part)

Spawning parallel agents is a token multiplier, not free speed — roughly an
order of magnitude more tokens than a single pass, and conflicting implicit
choices between parallel agents editing the same thing don't reconcile. The
field's hardest-won lesson is: **start with one agent; split only on measured
need; parallelize read-heavy independent work, serialize anything with
dependencies.** The orchestration rules encode exactly that, so "use more
agents" never becomes a reflex.

## Lifecycle discipline (keeping the read-path signal)

A growing log becomes noise by default. The defenses:

- The session journal is **archive-tier** — a complete record, mined on demand,
  never loaded wholesale.
- The read-path is a small, indexed, budgeted set (the memory index + the
  user's active plans + open threads). Exceeding the budget is the trigger to
  distill — size, not the calendar.
- Everything has a retirement rule. Threads close. State is overwritten, not
  appended. Stale entries are pruned the moment they stop being true.

The end product is only as good as the foundation it reads from.
