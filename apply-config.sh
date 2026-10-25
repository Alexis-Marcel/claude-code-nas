#!/bin/sh
# Applies the optional files of $CONFIG_DIR (default /config): tools, MCP
# servers, settings, instructions and skills. Run by start.sh; safe to run
# again by hand. A broken file is reported and skipped, never fatal.
set -u

CONFIG_DIR=${CONFIG_DIR:-/config}
CLAUDE_DIR=$HOME/.claude
MISE_CONF_D=$HOME/.config/mise/conf.d
STATE=$HOME/.local/state/claude-code-nas
mkdir -p "$CLAUDE_DIR/skills" "$MISE_CONF_D" "$STATE"

log() { echo "config: $*"; }

# Tools: /config/mise.toml and TOOLS="go@1.27 python npm:pnpm" become mise
# fragments; Claude's own `mise use -g` still writes ~/.config/mise/config.toml.
tools() {
  if [ -f "$CONFIG_DIR/mise.toml" ]; then
    ln -sfn "$CONFIG_DIR/mise.toml" "$MISE_CONF_D/10-config.toml"
  else
    rm -f "$MISE_CONF_D/10-config.toml"
  fi
  if [ -n "${TOOLS:-}" ]; then
    {
      echo "[tools]"
      for t in $TOOLS; do
        name=${t%@*}
        version=latest
        [ "$name" != "$t" ] && version=${t##*@}
        printf '"%s" = "%s"\n' "$name" "$version"
      done
    } > "$MISE_CONF_D/20-tools-env.toml"
  else
    rm -f "$MISE_CONF_D/20-tools-env.toml"
  fi
  # A no-op when everything is installed; the first start can take minutes.
  (cd "$HOME" && mise install) || log "some tools failed to install, see above"
}

# MCP servers: each entry of /config/mcp.json is (re)added at user scope.
# Servers that came from the file and left it are removed; servers added by
# hand are never touched.
mcp() {
  list=$STATE/mcp-servers
  touch "$list"
  if [ -f "$CONFIG_DIR/mcp.json" ]; then
    if ! names=$(jq -r '.mcpServers // {} | keys[]' "$CONFIG_DIR/mcp.json"); then
      log "mcp.json is not valid JSON, MCP servers left unchanged"
      return
    fi
  else
    names=
  fi
  while read -r name; do
    if ! printf '%s\n' "$names" | grep -qx "$name"; then
      claude mcp remove -s user "$name" >/dev/null 2>&1 && log "MCP server $name removed"
    fi
  done < "$list"
  : > "$list"
  for name in $names; do
    json=$(jq -c --arg n "$name" '.mcpServers[$n]' "$CONFIG_DIR/mcp.json")
    claude mcp remove -s user "$name" >/dev/null 2>&1
    if claude mcp add-json -s user "$name" "$json" >/dev/null; then
      echo "$name" >> "$list"
      log "MCP server $name"
    else
      log "MCP server $name rejected, see above"
    fi
  done
}

# Settings: keys from /config/settings.json win over ~/.claude/settings.json.
settings() {
  [ -f "$CONFIG_DIR/settings.json" ] || return
  user=$CLAUDE_DIR/settings.json
  [ -f "$user" ] || echo '{}' > "$user"
  if jq -s '.[0] * .[1]' "$user" "$CONFIG_DIR/settings.json" > "$user.new"; then
    mv "$user.new" "$user"
    log "settings.json merged"
  else
    rm -f "$user.new"
    log "settings.json is not valid JSON, settings left unchanged"
  fi
}

# Instructions and skills are linked, so editing /config is enough.
instructions() {
  target=$CLAUDE_DIR/CLAUDE.md
  if [ -f "$CONFIG_DIR/CLAUDE.md" ]; then
    if [ -e "$target" ] && ! [ -L "$target" ]; then
      log "$target exists and is not ours, /config/CLAUDE.md not linked"
    else
      ln -sfn "$CONFIG_DIR/CLAUDE.md" "$target"
    fi
  elif [ -L "$target" ]; then
    rm -f "$target"
  fi
}

skills() {
  for link in "$CLAUDE_DIR"/skills/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in
      "$CONFIG_DIR"/skills/*) [ -e "$link" ] || rm -f "$link" ;;
    esac
  done
  for dir in "$CONFIG_DIR"/skills/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    link=$CLAUDE_DIR/skills/$name
    if [ -e "$link" ] && ! [ -L "$link" ]; then
      log "skill $name exists in $CLAUDE_DIR/skills, not linked"
      continue
    fi
    ln -sfn "$CONFIG_DIR/skills/$name" "$link"
    log "skill $name"
  done
}

[ -f "$CONFIG_DIR/managed-settings.json" ] && log "managed-settings.json in effect"
tools
mcp
settings
instructions
skills
