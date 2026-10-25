FROM node:24-trixie-slim

ARG CLAUDE_CODE_VERSION=2.1.310
ARG GH_VERSION=2.103.2
ARG MISE_VERSION=2026.10.19
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git tmux ripgrep jq less procps openssh-client \
    && rm -rf /var/lib/apt/lists/*

# gh from its GitHub release, checked against the published checksums
RUN arch="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && tarball="gh_${GH_VERSION}_linux_${arch}.tar.gz" \
    && cd /tmp \
    && curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${tarball}" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" \
       | grep " ${tarball}\$" | sha256sum -c - \
    && tar xzf "${tarball}" \
    && mv "gh_${GH_VERSION}_linux_${arch}/bin/gh" /usr/local/bin/gh \
    && rm -rf /tmp/gh_*

# mise installs the user's tools into $HOME, without root.
RUN arch="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && case "$arch" in amd64) arch=x64 ;; esac \
    && tarball="mise-v${MISE_VERSION}-linux-${arch}.tar.gz" \
    && cd /tmp \
    && curl -fsSLO "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/${tarball}" \
    && curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/SHASUMS256.txt" \
       | grep " \./${tarball}\$\| ${tarball}\$" | sha256sum -c - \
    && tar xzf "${tarball}" \
    && mv mise/bin/mise /usr/local/bin/mise \
    && rm -rf /tmp/mise*

# Claude Code system-wide: $HOME is a volume, so nothing may live there.
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && npm cache clean --force

# The node image's UID 1000 user, renamed. Other UIDs work through `user:`.
RUN usermod -l claude -d /home/claude -m node && groupmod -n claude node \
    && mkdir -p /work && chown claude:claude /work \
    && mkdir -p /etc/claude-code \
    && ln -s /config/managed-settings.json /etc/claude-code/managed-settings.json

COPY --chmod=755 start.sh apply-config.sh reaper.sh healthcheck.sh /usr/local/bin/

# Updates come from a new image, not from the read-only container.
# User-space installs (mise, npm -g, pip --user, uv tool) land in the home
# volume; an image that changes HOME must set these paths again.
ENV DISABLE_AUTOUPDATER=1 \
    HOME=/home/claude \
    PATH=/home/claude/.local/share/mise/shims:/home/claude/.local/bin:$PATH \
    NPM_CONFIG_PREFIX=/home/claude/.local \
    MISE_YES=1 \
    MISE_TRUSTED_CONFIG_PATHS=/config \
    WORKSPACE=/work \
    IDLE_MIN=60 \
    LANG=C.UTF-8 \
    TERM=xterm-256color

USER claude
WORKDIR /work

HEALTHCHECK --interval=1m --timeout=10s --start-period=1m CMD ["/usr/local/bin/healthcheck.sh"]
CMD ["/usr/local/bin/start.sh"]
