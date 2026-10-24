# Roadmap

## Planned: AI actions ("Action Type" dropdown)

Status: idea, not started.

Today a timer's finish action is a terminal command. Add an **Action Type**
dropdown next to the action input so the same box can drive an AI agent:

| Action Type        | What the input box means                          |
|--------------------|---------------------------------------------------|
| Terminal Command   | A shell command (current behavior)                |
| Claude Agent       | A prompt sent to Claude Code when the timer ends  |
| Codex Agent        | A prompt sent to Codex when the timer ends        |

Example: a timer set to "Claude Agent" with a prompt asking for a backup that
needs judgment (check what changed, decide what to keep, run it). When the timer
completes, the prompt runs, the agent does the work, and its output goes into the
timer's action log exactly like terminal output does now (time, success or
failure, text), plus the usual notification.

### Design notes

- Each timer remembers its action type. Saved actions and the log record it too,
  so a log row says which kind of run it was.
- Run the agent non-interactively through its command-line mode (for Claude Code
  `claude -p "<prompt>"`, for Codex `codex exec "<prompt>"`), capture stdout and
  stderr into the same log path used by terminal actions. Confirm the exact flags
  against the installed versions when implementing.
- Safety needs a decision before building, because the agent runs unattended:
  which permission mode it gets, which working directory, and whether a prompt
  may change files or run commands without asking. Default to the most
  restricted mode and make anything broader an explicit per-timer choice.
- Add a timeout and a clear "agent failed" log entry (exit code, last output),
  since agent runs can be slow, cost money, or need login.
- Repeating timers with an agent action multiply cost; show a warning when
  Repeat is on.
- Long agent output: keep the log trimmed as now, and consider writing the full
  transcript to a file and linking it from the log entry.
- Show a missing-tool message (not a silent failure) if `claude` or `codex` is
  not installed or not logged in on that machine.
