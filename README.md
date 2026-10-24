# claude-code-nas

Claude Code always on, on your NAS: talk to it from the Claude app (Remote Control),
while it runs in a locked-down container.

> **Unofficial project.** Not affiliated with, endorsed by, or supported by Anthropic.
> "Claude" and "Claude Code" are Anthropic's trademarks, used here only to say what this
> runs. The image installs the published `@anthropic-ai/claude-code` package unchanged;
> your use of it stays subject to Anthropic's terms.

## What you get

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

## Configuration

| Variable | Default | |
|---|---|---|
| `REMOTE_CONTROL_NAME` | container hostname | name shown in the Claude app |
| `IDLE_MIN` | `60` | minutes before an idle app session is stopped |
| `REAPER_INTERVAL` | `600` | seconds between two reaper checks |
| `WORKSPACE` | `/work` | Claude's working directory |

Two volumes hold everything that must persist: `/home/claude` (login, settings, history:
keep the whole folder, `.claude.json` sits next to `.claude/`) and `/work`.

## Adding your tools

The image only carries Claude Code, git, gh, tmux, ripgrep and jq. Add your toolchains
in your own image:

```dockerfile
FROM ghcr.io/alexis-marcel/claude-code-nas:latest
USER root
RUN apt-get update && apt-get install -y --no-install-recommends golang python3 \
    && rm -rf /var/lib/apt/lists/*
USER claude
```

## License

[MIT](LICENSE)
