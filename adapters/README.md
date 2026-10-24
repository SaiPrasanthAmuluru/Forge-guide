# Adapters

The rules, playbooks, skills and scripts in this repo are plain Markdown and shell. They do not
depend on any one agent. An adapter is only a convenience that wires them into a specific tool.
None is required.

| Folder | For | What it contains |
|---|---|---|
| `generic/` | Any agent that can read files | Paste-ready prompts for review, generation and reports |
| `claude-code/` | Claude Code | A read-only reviewer subagent and an optional PR-blocking hook |

## What an agent needs

- **Required:** read files from the toolkit folder and the project.
- **Helpful:** run shell commands (the scripts only need `git` and `bash`). Without a shell, ask
  the developer to run a script and paste the output, or use plain `git diff` and text search.
- **Optional:** a way to start a separate reviewer session. A fresh context is what makes the
  review independent; a human review counts too.

## Adding an adapter for another tool

Keep the adapter to wiring only: where the tool looks for instructions (point it at `AGENTS.md`),
how it starts a separate reviewer context, and how it limits tools. Do not copy rules into it;
link to the files so there is one copy to maintain.
