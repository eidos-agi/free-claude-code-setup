# Eidos AGI trilogy CLIs (`research-md`, `visionlog`, `ike-md`) have no CLI surface

**Symptom:** `research-md --help` hangs. `visionlog --help` hangs. `ike-md --help` hangs. No output, no prompt return, no obvious error.

**Cause:** The trilogy packages are MCP (Model Context Protocol) servers, not standalone CLIs. The shell command does one thing: start an MCP server reading JSON-RPC over stdin. With no client connected and no terminator, it sits in `stdin.read()` forever.

The package metadata at https://eidosagi.com calls them "CLIs" loosely; they're really stdio MCP servers. Documented invocation form on PyPI:

```json
{
  "mcpServers": {
    "visionlog": {
      "command": "/path/to/visionlog",
      "args": ["mcp", "start"]
    }
  }
}
```

`mcp start` is the only documented subcommand. There is no `--help`, no `--version`, no `init` from the shell. All operations (project_init, vision_create, goal_create, etc.) happen through MCP tool calls from a connected LLM client.

**Fix:** Don't try to drive them from the shell. Configure them in `.mcp.json` and invoke from inside Claude Code (or another MCP client) via the MCP tool calls each server exposes:

- **visionlog**: `project_init`, `project_set`, `visionlog_boot`, `visionlog_guide`, `goal_create`, `goal_list`, `decision_create`, `guardrail_create`, `sop_create`, …
- **research-md**: decision-brief tools (specifics not yet documented; explore via MCP `tools/list`).
- **ike-md**: task/milestone tools (specifics not yet documented).

**Install via uv tool** (so the binaries land at `~/.local/bin/`):

```bash
uv tool install research-md
uv tool install visionlog-md
uv tool install ike-md
```

**Trap:** If you `timeout 3` one of these in a script, the script exits cleanly but you've lost 3 seconds with nothing to show. Test connectivity instead by spawning the MCP server with `mcp start`, sending an `initialize` JSON-RPC over stdin, and parsing the response — that's faster and actually proves the server is healthy.

**Sources:** Discovered 2026-04-24 trying to bootstrap the trilogy on Shadow PC. PyPI package summary at https://pypi.org/project/visionlog-md/ documents the MCP-only invocation; org listing at https://github.com/eidos-agi exists but individual repos returned 404 on the `research-md` / `visionlog-md` / `ike-md` names.
