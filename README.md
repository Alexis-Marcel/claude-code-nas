# claude-code-nas

Claude Code always on, on your NAS: talk to it from the Claude app (Remote Control),
while it runs in a locked-down container.

> **Unofficial project.** Not affiliated with, endorsed by, or supported by Anthropic.
> "Claude" and "Claude Code" are Anthropic's trademarks, used here only to say what this
> runs. The image installs the published `@anthropic-ai/claude-code` package unchanged;
> your use of it stays subject to Anthropic's terms.

## What you get

- Your AI's environment from a folder of standard files: tools, MCP servers, settings,
  instructions, skills. No Dockerfile needed.
- `claude remote-control` running 24/7 in tmux, restarted if it exits.
- Sessions that survive `docker stop`: the server is stopped cleanly and resumes them.
- An idle-session reaper: sessions opened from the app that stay idle for `IDLE_MIN`
  minutes are stopped to free memory, and come back on the next message.
- A read-only container with all capabilities dropped, running as any non-root UID.

Remote Control needs a Claude Pro or Max subscription (API keys are not supported).

## Quick start

```sh
git clone https://github.com/Alexis-Marcel/claude-code-nas.git && cd claude-code-nas
mkdir -p data/home data/work && sudo chown -R 1000:1000 data
docker compose up -d --build
```

Log in once (pick the subscription login, open the URL, paste the code back), then `/exit`:

```sh
docker exec -it claude-code-nas claude
```

If Remote Control asks a question on its first run, answer it in its tmux window
(detach with `Ctrl-b d`):

```sh
docker exec -it claude-code-nas tmux attach -t remote
```

In the Claude app, open **Code**: the session named `REMOTE_CONTROL_NAME` is there.

## Image

`ghcr.io/alexis-marcel/claude-code-nas` (amd64), tagged `latest` and with the Claude Code
version it carries (e.g. `2.1.310`). A daily job publishes a new image when a new Claude
Code version is released; the auto-updater is off inside the container. To use the
published image instead of building, run `docker compose pull && docker compose up -d`.

## Configuration

| Variable | Default | |
|---|---|---|
| `REMOTE_CONTROL_NAME` | container hostname | name shown in the Claude app |
| `IDLE_MIN` | `60` | minutes before an idle app session is stopped |
| `REAPER_INTERVAL` | `600` | seconds between two reaper checks |
| `WORKSPACE` | `/work` | Claude's working directory |
| `TOOLS` | | tools to install, e.g. `python@3.13 terraform` |
| `CONFIG_DIR` | `/config` | where the files above are read from |

Two volumes hold everything that must persist: `/home/claude` (login, settings, history:
keep the whole folder, `.claude.json` sits next to `.claude/`) and `/work`.

## Give your AI its environment

Put any of these files in `./config` (mounted read-only on `/config`). All are optional,
each uses its tool's own format, and they are applied at every start: edit, then
`docker compose restart`. Copy [`examples/config`](examples/config) to start.

| File | What it gives your AI | Format |
|---|---|---|
| `mise.toml` | Languages and CLIs: Python, Node, Go, Java, Rust, Terraform, ruff, pnpm… installed into the home volume, no root | [mise](https://mise.jdx.dev/configuration.html) |
| `mcp.json` | MCP servers (http or local commands); `${VAR}` reads secrets from the environment | the `mcpServers` block from any MCP server's docs |
| `settings.json` | Claude Code settings (permissions, model…), merged into `~/.claude/settings.json` | [settings](https://code.claude.com/docs/en/settings) |
| `managed-settings.json` | Rules Claude cannot lift, such as `deny` rules | same format, highest precedence |
| `CLAUDE.md` | Standing instructions for every session | [memory](https://code.claude.com/docs/en/memory) |
| `skills/<name>/SKILL.md` | Skills | [skills](https://code.claude.com/docs/en/skills) |

For a quick setup without files, `TOOLS="python@3.13 terraform"` does the same as a
`mise.toml`. Claude can also install a tool itself when it needs one (`mise use -g go`).

- **MCP servers in other containers**: put them on the same Docker network and use the
  container name in the URL (`http://notes-mcp:8765/mcp`), or use the NAS IP.
- **Servers added by hand** with `claude mcp add` are kept; servers removed from
  `mcp.json` are removed at the next start.
- **First start with tools** takes a minute or two (`docker logs` shows progress); later
  starts reuse them.

### System packages

The container is read-only and not root, so `apt install` is not possible inside it.
For the rare tool that needs system libraries (for example PHP with `grpc`), extend
the image:

```dockerfile
FROM ghcr.io/alexis-marcel/claude-code-nas:latest
USER root
RUN apt-get update && apt-get install -y --no-install-recommends libvips-tools \
    && rm -rf /var/lib/apt/lists/*
USER claude
```

## License

[MIT](LICENSE)
