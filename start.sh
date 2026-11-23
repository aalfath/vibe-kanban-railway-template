#!/bin/sh
# Vibe Kanban start script for Railway.
# - Everything the app writes (database, settings, agent logins, repos, worktrees)
#   goes under /data, the Railway volume.
# - Vibe Kanban has no login of its own, so Caddy sits in front of it on $PORT
#   with HTTP basic auth (VIBE_KANBAN_USERNAME / VIBE_KANBAN_PASSWORD).
# - If either process stops, the script exits non-zero so Railway restarts it.
set -eu

DATA_DIR="${VIBE_KANBAN_DATA_DIR:-/data}"
export PORT="${PORT:-8080}"
export VK_INTERNAL_PORT="${VK_INTERNAL_PORT:-3001}"
export VIBE_KANBAN_USERNAME="${VIBE_KANBAN_USERNAME:-admin}"

if [ -z "${VIBE_KANBAN_PASSWORD:-}" ]; then
  echo "vibe-kanban-start: VIBE_KANBAN_PASSWORD is empty; refusing to start an open server." >&2
  exit 1
fi
if [ "$VK_INTERNAL_PORT" = "$PORT" ]; then
  echo "vibe-kanban-start: VK_INTERNAL_PORT must differ from PORT." >&2
  exit 1
fi

if [ "$(id -u)" = "0" ]; then
  mkdir -p "$DATA_DIR"
  # Hand the (fresh) volume to the unprivileged `node` user, then re-run as it.
  if [ "$(stat -c %u "$DATA_DIR")" != "1000" ]; then
    chown -R node:node "$DATA_DIR"
  fi
  # Worktrees live in /var/tmp/vibe-kanban upstream; keep them on the volume.
  mkdir -p "$DATA_DIR/worktrees"
  chown node:node "$DATA_DIR/worktrees"
  rm -rf /var/tmp/vibe-kanban
  ln -s "$DATA_DIR/worktrees" /var/tmp/vibe-kanban
  # Keep the environment: the deployer's agent keys (ANTHROPIC_API_KEY, ...) must reach the agents.
  export VIBE_KANBAN_DATA_DIR="$DATA_DIR"
  exec setpriv --reuid=node --regid=node --init-groups -- "$0" "$@"
fi

# ---- from here on we run as `node` ----
export HOME="$DATA_DIR/home"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export npm_config_cache="$HOME/.npm"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$DATA_DIR/repos"
[ -e "$HOME/repos" ] || ln -s "$DATA_DIR/repos" "$HOME/repos"

# Git defaults for commits made by agents (the deployer can change them in a terminal).
git config --global --get user.name >/dev/null 2>&1 || git config --global user.name "Vibe Kanban"
git config --global --get user.email >/dev/null 2>&1 || git config --global user.email "vibe-kanban@localhost"
git config --global init.defaultBranch main
# Small memory footprint for git on 0.5 GB plans.
git config --global pack.threads 1
git config --global core.packedGitLimit 64m
git config --global core.packedGitWindowSize 16m
git config --global pack.windowMemory 64m
git config --global pack.deltaCacheSize 16m

# Thread and allocator caps: Railway shows the host's CPUs inside a 1 vCPU service.
CPUS="${VK_CPUS:-}"
if [ -z "$CPUS" ]; then
  if [ -r /sys/fs/cgroup/cpu.max ]; then
    CPUS=$(awk '{ if ($1 == "max") print 2; else { c = int(($1 + $2 - 1) / $2); if (c < 1) c = 1; if (c > 4) c = 4; print c } }' /sys/fs/cgroup/cpu.max)
  else
    CPUS=2
  fi
fi
export TOKIO_WORKER_THREADS="${TOKIO_WORKER_THREADS:-$CPUS}"
export RAYON_NUM_THREADS="${RAYON_NUM_THREADS:-$CPUS}"
export UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-$CPUS}"
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"

# Caddy basic auth needs a bcrypt hash of the password.
VK_PASSWORD_HASH=$(caddy hash-password --plaintext "$VIBE_KANBAN_PASSWORD")
export VK_PASSWORD_HASH
unset VIBE_KANBAN_PASSWORD

export RUST_LOG="${RUST_LOG:-info}"

# Optional: GitHub token for private repos, pushes and pull requests (gh CLI + git).
if [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
  export GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
  git config --global credential.https://github.com.helper '!/usr/local/bin/gh auth git-credential'
fi

# Optional: clone repos listed in GIT_REPOS (space or comma separated URLs) into
# $DATA_DIR/repos on first boot, in the background so the health check isn't held up.
if [ -n "${GIT_REPOS:-}" ]; then
  (
    for url in $(echo "$GIT_REPOS" | tr ',' ' '); do
      name=$(basename "$url" .git)
      [ -n "$name" ] || continue
      if [ ! -d "$DATA_DIR/repos/$name/.git" ]; then
        echo "vibe-kanban-start: cloning $name into $DATA_DIR/repos/$name"
        git clone --quiet "$url" "$DATA_DIR/repos/$name" || echo "vibe-kanban-start: clone of $name failed" >&2
      fi
    done
  ) &
fi

# Vibe Kanban listens only on loopback; Caddy is the only public listener.
HOST=127.0.0.1 PORT="$VK_INTERNAL_PORT" BACKEND_PORT="$VK_INTERNAL_PORT" \
  VK_ALLOWED_ORIGINS="${VK_ALLOWED_ORIGINS:-}" \
  /usr/local/bin/vibe-kanban &
VK_PID=$!
caddy run --config /etc/vibe-kanban/Caddyfile --adapter caddyfile &
CADDY_PID=$!

trap 'kill -TERM "$VK_PID" "$CADDY_PID" 2>/dev/null || true' TERM INT

# Poll (BusyBox-safe): exit non-zero as soon as either process stops.
while kill -0 "$VK_PID" 2>/dev/null && kill -0 "$CADDY_PID" 2>/dev/null; do
  sleep 2
done
echo "vibe-kanban-start: a process stopped; exiting so Railway restarts the service." >&2
kill -TERM "$VK_PID" "$CADDY_PID" 2>/dev/null || true
exit 1
