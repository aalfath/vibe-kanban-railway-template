#!/bin/sh
# npx replacement for Vibe Kanban on small Railway plans.
#
# Vibe Kanban starts coding agents with `npx -y <package>@<version> ...`. Plain npx
# keeps an `npm exec` parent of about 350 MB resident next to every agent and
# downloads each agent again into a large cache, which gets a 0.5 GB service
# OOM-killed. This shim installs each package spec once (one install at a time,
# under a lock) into $VK_AGENTS_DIR on the volume and then runs the package's
# binary directly, so only the agent itself stays in memory.
#
# At boot Vibe Kanban also starts some agents just to list their models. When
# that start-up check (run from $VK_IDLE_DIR) asks for an agent that isn't
# installed yet, the shim declines instead of downloading it; the agent is
# installed the first time you actually use it.
set -eu

REAL_NPX=/usr/local/lib/node_modules/npm/bin/npx-cli.js

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes|-q|--quiet) shift ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || exec node "$REAL_NPX"
case "$1" in
  -*) exec node "$REAL_NPX" "$@" ;;
esac

spec="$1"; shift
case "$spec" in
  @*/*@*) name="@${spec#@}"; name="${name%@*}" ;;
  @*/*)   name="$spec" ;;
  *@*)    name="${spec%@*}" ;;
  *)      name="$spec" ;;
esac

AGENTS_DIR="${VK_AGENTS_DIR:-$HOME/.vk-agents}"
key=$(printf '%s' "$spec" | tr -c 'A-Za-z0-9._-' '_')
dir="$AGENTS_DIR/$key"

if [ ! -f "$dir/.installed" ]; then
  if [ -n "${VK_IDLE_DIR:-}" ] && [ "$(pwd -P)" = "$VK_IDLE_DIR" ]; then
    echo "vk-npx: $spec is not installed yet; skipping the start-up check (it installs on first use)." >&2
    exit 1
  fi
  mkdir -p "$AGENTS_DIR"
  (
    flock 9
    if [ ! -f "$dir/.installed" ]; then
      echo "vk-npx: installing $spec (first use only)..." >&2
      tmp="$dir.tmp.$$"
      rm -rf "$tmp"
      mkdir -p "$tmp"
      printf '{"name":"vk-agent","private":true}\n' > "$tmp/package.json"
      NODE_OPTIONS="--max-old-space-size=${VK_NPM_HEAP_MB:-256}" \
        npm install --prefix "$tmp" --no-audit --no-fund --no-package-lock \
          --omit=dev --loglevel=error --maxsockets=4 \
          --cache "$tmp/.npm-cache" "$spec" >&2
      rm -rf "$tmp/.npm-cache"
      rm -rf "$dir"
      mv "$tmp" "$dir"
      touch "$dir/.installed"
    fi
  ) 9>"$AGENTS_DIR/.install.lock"
fi

pkgdir="$dir/node_modules/$name"
bin=$(node -e '
const p = require(process.argv[1] + "/package.json");
const want = process.argv[2].replace(/^@[^/]+\//, "");
let b = p.bin;
if (typeof b === "string") { console.log(want); process.exit(0); }
const keys = Object.keys(b || {});
if (keys.length === 0) process.exit(3);
console.log(keys.length === 1 ? keys[0] : (keys.includes(want) ? want : keys[0]));
' "$pkgdir" "$name") || { echo "vk-npx: $spec has no executable" >&2; exit 1; }

exec "$dir/node_modules/.bin/$bin" "$@"
