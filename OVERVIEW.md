# Deploy and Host Vibe Kanban on Railway

Vibe Kanban is an open-source web app (Apache-2.0) for running coding agents such as Claude Code, Codex, Gemini CLI, OpenCode and Qwen Code on your git repos. Each task gets its own workspace with a branch, a git worktree, a terminal and a diff view, so you can review the agent's changes and send follow-ups.

## About Hosting Vibe Kanban

This template runs Vibe Kanban v0.1.46.1794744340 as one service, built from our GitHub repo with the release's own Linux binary (SHA-256 checked). Vibe Kanban has no login of its own, so Caddy sits in front of it with HTTP basic auth: user `admin` and a generated password in the `VIBE_KANBAN_PASSWORD` variable. Everything is stored on a volume at `/data`: the SQLite database, settings, agent logins, installed agents, your repos and the agents' worktrees. The only prompt is `ANTHROPIC_API_KEY` for Claude Code, the default agent. Each agent is installed on first use and kept on the volume. bloop's hosted kanban projects were retired in 2026, so the template runs Vibe Kanban's workspaces; no sign-in is needed.

## Common Use Cases

* Run Claude Code, Codex or Gemini CLI on a repo from any browser, without keeping your laptop on
* Run several agent tasks side by side, each on its own branch and worktree, and review the diffs
* Let an agent prepare a branch and open a pull request with the GitHub CLI

## Dependencies for Vibe Kanban Hosting

* An API key for at least one coding agent (Anthropic for Claude Code; OpenAI, Gemini and others optional)
* A Railway volume for the database, agents and repos (included)

### Deployment Dependencies

* Vibe Kanban source and releases: https://github.com/BloopAI/vibe-kanban/releases/tag/v0.1.46.1794744340
* Vibe Kanban docs: https://vibekanban.com/docs
* Template repo: https://github.com/aalfath/vibe-kanban-railway-template
* Anthropic API keys: https://console.anthropic.com/settings/keys

### Implementation Details

After deploy, open the public URL and log in as `admin` with `VIBE_KANBAN_PASSWORD` from the service's Variables tab. On the welcome screen choose "Don't sign in". To add repos, add a `GIT_REPOS` variable (git URLs separated by spaces or commas; they are cloned into `/data/repos` on boot) or create a repo from the UI. Add `GH_TOKEN` for private repos, pushes and pull requests, and `OPENAI_API_KEY`, `GEMINI_API_KEY` and so on for other agents.

Agents run with full permissions inside the container (upstream's defaults), so only give them repos and tokens you trust them with. Docker-in-Docker is not available.

Resources: about 25 MB idle; one Claude Code run peaked at about 170 MB in our 0.5 GB test, so the Free plan works for one agent at a time. Use 1-2 GB for parallel agents, large repos or dev servers.

Updates: when we publish a new Vibe Kanban release to the template repo, Railway shows an "update available" notice on your project; the changes are listed in the repo's CHANGELOG.md, and your data stays on the volume.

## Why Deploy Vibe Kanban on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Vibe Kanban on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
