[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/vibe-kanban?utm_medium=integration&utm_source=button&utm_campaign=vibe-kanban)

# Vibe Kanban on Railway

One-click Railway template for [Vibe Kanban](https://github.com/BloopAI/vibe-kanban) (Apache-2.0): a web UI for running coding agents (Claude Code, Codex, Gemini CLI, OpenCode, Qwen Code, Copilot and others) on your git repos. Each workspace gets its own branch and git worktree, a terminal and a diff view, and you review the agent's changes and send follow-ups from the browser.

**Version:** Vibe Kanban **v0.1.46.1794744340** (2026-11-15). Upstream publishes no container image, so the `Dockerfile` downloads the release's own Linux binary (`linux-x64-vibe-kanban.zip`, the file `npx vibe-kanban` uses) and checks its SHA-256 (`519823fb…5f2`, from the release's `manifest.json`). Base image `node:24.22.3-bookworm-slim@sha256:dc26ae92…1c54` (agents run on Node), Caddy `2.11.9-alpine@sha256:003a9780…f0` for the login, GitHub CLI 2.105.0 (SHA-256 checked).

> **About the project's status.** bloop, the company behind Vibe Kanban, shut down in April 2026 and the project continues as community-maintained open source. Since v0.1.44 the hosted kanban *projects* (issues, boards) are export-only; what this template runs is the part that still works fully: **workspaces** that run coding agents on your repos. You don't need to sign in to anything; choose "Don't sign in" on first start.

## What the template deploys

| Service | What it does | State |
|---|---|---|
| `Vibe Kanban` | Vibe Kanban server (on `127.0.0.1`) behind Caddy basic auth on Railway's `PORT`; health check `/healthz` | Volume at `/data`: SQLite database and settings, agent logins and installed agents, your repos (`/data/repos`) and the agents' worktrees |

No database service is needed.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `ANTHROPIC_API_KEY` | *(you enter it)* | Key for Claude Code, the default agent. Get one at https://console.anthropic.com/settings/keys |
| `VIBE_KANBAN_PASSWORD` | `${{secret(32)}}` | Generated. Password for the web UI (Vibe Kanban has no login of its own) |
| `VIBE_KANBAN_USERNAME` | `admin` | User name for the web UI |
| `GIT_REPOS` | *(empty, optional)* | Git URLs to clone into `/data/repos` on boot, separated by spaces or commas |
| `PORT` | `8080` | Port Caddy listens on |

Add `GH_TOKEN` (a GitHub token) for private repos, pushes and pull requests; `git` and `gh` pick it up. Other agents read their usual variables; add them in Railway's **Variables** tab: `OPENAI_API_KEY` (Codex), `GEMINI_API_KEY` (Gemini CLI), `DASHSCOPE_API_KEY` (Qwen Code), and so on. Agents can also be signed in from the terminal of a workspace; their logins stay on the volume.

## After deploy

1. Open the public URL and log in with `admin` and the `VIBE_KANBAN_PASSWORD` from the service's **Variables** tab.
2. On the welcome screen choose **Don't sign in** (bloop's cloud is shut down; nothing needs it).
3. Add a repo: put its URL in `GIT_REPOS` (it is cloned to `/data/repos/<name>` on the next deploy), or create a new repo from the UI under `/data/repos`.
4. Create a workspace, pick the repo and an agent, describe the task, and review the diff when the agent is done.

Each agent is installed the first time you use it (Claude Code is about 235 MB) and is kept on the volume, so later runs start at once.

## Safety defaults

- The web UI and API sit behind HTTP basic auth with a generated password. The start script refuses to start when `VIBE_KANBAN_PASSWORD` is empty. Only `/healthz` answers without a login.
- Vibe Kanban runs as the unprivileged `node` user; root is only used to hand the fresh Railway volume to that user.
- **Agents run with full permissions inside the container** (upstream's defaults, e.g. Claude Code's `--dangerously-skip-permissions`): they can run any command and reach the network. Only give them repos and tokens you're happy for them to use. No Docker-in-Docker or privileged mode.
- If the server or Caddy stops, the container exits non-zero, so Railway's on-failure restart brings it back.

## Resources

Idles at about 25 MB RAM. A Claude Code run peaked at about 170 MB in our 0.5 GB test, so Railway's Free plan works for one agent at a time. Give it 1–2 GB for several agents in parallel, large repos or dev servers.

What we changed for small plans: Vibe Kanban starts agents with `npx -y <agent>@<version>`, which keeps a ~350 MB `npm exec` process next to every agent and, at boot, starts OpenCode and Claude Code just to list their models (a 0.5 GB service was OOM-killed on first boot). Our `npx` wrapper (`npx-shim.sh`) installs each pinned agent version once on the volume and runs it directly, and skips that boot-time check for agents you haven't used yet.

## Updates

Railway shows deployers an "update available" notice when this repo's `main` changes. Each update moves `VK_TAG`/`VK_SHA256` in the `Dockerfile` to a new upstream release and is described in [CHANGELOG.md](CHANGELOG.md), breaking changes first. Your data stays on the volume.

## Local test

```sh
docker build -t vibe-kanban .
docker run --rm -p 8080:8080 -e VIBE_KANBAN_PASSWORD=change-me -e ANTHROPIC_API_KEY=sk-ant-... \
  -v vibe-kanban-data:/data vibe-kanban
# open http://localhost:8080 and log in as admin / change-me
```

## Licence

Vibe Kanban is licensed Apache-2.0 by bloop and its contributors. The files in this repo are small wrappers around it.
