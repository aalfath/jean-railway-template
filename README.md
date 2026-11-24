[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/jean?utm_medium=integration&utm_source=button&utm_campaign=jean)

# Jean on Railway

Jean is an open-source dev environment for AI coding agents by coollabs. From one web UI you add Git projects, open isolated worktrees, run Claude Code, Codex, OpenCode and other agents on them, review diffs, use terminals, and commit or open pull requests. This template runs its headless `jean-server` (v1.0.16).

## About Hosting Jean

Jean's headless server is a single Rust binary that serves the web UI over HTTP and WebSocket. This template builds it from the official `ghcr.io/coollabsio/jean-server` image, pinned by version and digest, on a pinned Node.js 24 base, with Claude Code, Codex and OpenCode preinstalled. One Railway volume at `/home/jean` keeps projects, worktrees, sessions, settings and agent logins across redeploys. Access is locked by an access token that Railway generates on deploy. After deploy you open the URL with the token once, add a Git repository, and sign in to an agent with your own subscription or API key.

## Common Use Cases

* Run Claude Code, Codex or OpenCode on your repositories from a browser or phone, without a local machine
* Keep several agent sessions running in parallel, each in its own Git worktree, and review their diffs before committing
* Give a remote, always-on dev box to the Jean desktop app as a "remote server" connection

## Dependencies for Jean Hosting

* One Railway service built from `aalfath/jean-railway-template` (Jean server, web UI and agent CLIs)
* One Railway volume mounted at `/home/jean`
* Your own agent account or API key (Anthropic, OpenAI or any provider OpenCode supports), added after deploy

### Deployment Dependencies

* Jean: https://github.com/coollabsio/jean
* Jean v1.0.16 release: https://github.com/coollabsio/jean/releases/tag/v1.0.16
* Headless server docs: https://github.com/coollabsio/jean/blob/v1.0.16/docs/headless-server.md
* Template source: https://github.com/aalfath/jean-railway-template

### Implementation Details

**Services.** `Jean` is the only service. It listens on `PORT` 3456, answers `/healthz` for Railway's health check, and restarts on failure.

**Sign in.** Open the service's Variables tab, copy `JEAN_TOKEN`, then visit `https://YOUR-DOMAIN/?token=YOUR-JEAN-TOKEN` once. Jean swaps the token for a browser session cookie and removes it from the URL. Keep the token private: anyone who has it can run commands on the server. To revoke access, change `JEAN_TOKEN` and redeploy. The same URL and token work in the Jean desktop app under Connections, then Add remote, then Existing URL.

**Agents.** Claude Code, Codex and OpenCode are preinstalled and detected under "System PATH". Sign in from Jean's settings or a Jean terminal (`claude`, `codex login --device-auth`, `opencode auth login`). Logins are stored on the volume. Railway does not allow the Linux user namespaces that Codex's sandbox needs, so run Codex sessions in Jean's Yolo (full access) mode. Claude Code and OpenCode work in every mode. Other agents that Jean installs through npm go to `/home/jean/.local` on the volume.

**Memory.** Jean itself idles at about 30 MB. One Claude Code turn at a 0.5 GB limit peaked near 480 MB in our test, so the Free plan works for light use, but give the service at least 1 GB (Hobby or higher) for real agent sessions or several at once. Jean's in-app "Install Claude CLI" button downloads a 370 MB binary into memory: use the preinstalled CLI instead on small plans.

**Not included.** Docker inside the container, the desktop app's built-in browser, and "open in editor" actions are not available on Railway.

**Updates.** The template builds from a GitHub repository, so when we publish a new Jean version Railway shows an update notice in your project, and you choose when to apply it. Jean's own "Update & restart" button does not apply to containers. Your volume is kept across updates.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `JEAN_TOKEN` | `${{secret(48)}}` | Access token for the web UI and API. Generated on deploy; at least 24 characters, letters, digits and `. _ ~ -` only. Change it and redeploy to sign every browser out. |
| `PORT` | `3456` | Port Jean listens on. Railway's domain points at it. |

Agent keys (for example `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`) are optional: add them as service variables if you prefer keys to signing in from Jean.

## What's in the image

* `jean-server` and `gh` from `ghcr.io/coollabsio/jean-server:v1.0.16@sha256:52df17e2623c14aa075015421efea6ac42f9cb0dcaf5fa5667e722f3199651a3`
* Node.js 24.22.3 (`node:24.22.3-bookworm-slim`, pinned by digest), git, ripgrep, openssh-client
* Claude Code 2.1.331, Codex 0.172.0 and OpenCode 1.19.6 in `/opt/agents` (auto-update off; we bump them with each template update)
* `start.sh`: checks `JEAN_TOKEN`, binds to `PORT` on all interfaces, sizes thread pools to the service's CPUs, prepares the volume and runs Jean as the `jean` user (UID 1000). Any crash exits non-zero so Railway restarts the service.

## How updates reach you

This template builds from this repository. When we merge a new Jean version to `main`, Railway shows an "update available" notice in projects deployed from the template; you choose when to apply it. Read `CHANGELOG.md` first: breaking changes are listed at the top of each entry. Your `/home/jean` volume is kept.

## Why Deploy Jean on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Jean on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
