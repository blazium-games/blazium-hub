# Blazium Hub

Desktop Hub for [Blazium](https://blazium.app): browse editor builds on the public CDN, manage projects and installs through **blazium-cli**, and handle **`blazium://`** deep links.

Requires **[blazium-cli](https://github.com/blazium-games/blazium-cli)** for install/open/project mutations (shared `%APPDATA%\blazium\hub.json` / `~/.config/blazium/hub.json`).

## Community

- Official website: [https://blazium.app/](https://blazium.app/)
- IndieDB blog: [https://www.indiedb.com/engines/blazium-engine](https://www.indiedb.com/engines/blazium-engine)
- Official community: [Blazium Discord](https://discord.gg/sZaf9KYzDp)
- Docs: [docs.blazium.app](https://docs.blazium.app)

## Ecosystem

| Product | Role | Release |
|---------|------|---------|
| [CLI](https://github.com/blazium-games/blazium-cli) | Install editors, projects, remote control, Steam/itch deploy | Linux and Windows, x86_64 and x86_32. Catalog: [cli.json](https://cdn.blazium.app/cli/cli.json) |
| [Hub](https://github.com/blazium-games/blazium-hub) | Desktop companion; installers bundle the CLI | Linux and Windows, x86_64 and x86_32. Engine builds track `blazium_4.8` |
| [Crash reporter](https://github.com/blazium-games/blazium_crash_reporter) | Sidecar UI for engine and Hub crash reports | Linux and Windows, x86_64 and x86_32. Catalog: [crash_reporter.json](https://cdn.blazium.app/crash_reporter/crash_reporter.json). Engine builds track `blazium_4.8` |
| [Toolchain](https://github.com/blazium-games/blazium-toolchain) | PS1, PS2, N64, and Interactive DVD | Linux and Windows, x86_64 and x86_32. Catalog: [toolchain.json](https://cdn.blazium.app/toolchain/toolchain.json) |
| [Skills](https://github.com/blazium-games/blazium-skills) | Agent skill packs for Claude, Cursor, Codex, and Grok | Own semver, separate from the 0.8.x API baseline. Catalog: [skills.json](https://cdn.blazium.app/skills/skills.json) |
| [Subagents](https://github.com/blazium-games/blazium-subagents) | Studio roster that loads those skills | Own semver. Catalog: [subagents.json](https://cdn.blazium.app/subagents/subagents.json) |

## Features

- **Projects** — list / add / remove / open the editor / run the game via `blazium-cli --json`
- **Editors** — CDN catalogs (`release` / `nightly`) + CLI install/uninstall
- **News** — Blazium articles from `cdn.blazium.app/articles/rss.xml`, readable in-app (BBCode body + external `hosts` links from each article’s `meta.json`)
- **Settings** — CLI path, editor install path, close-to-tray (Windows), CLI upgrade check
- **System tray** (Windows) — show, recent projects, quit
- **URI scheme** `blazium://` — registered by Windows/Linux installers

## Input hardening

Untrusted ingress (CDN, News BBCode/`hosts`, SingleInstance IPC, `hub_remote.json`, CLI JSON, URIs, settings paths) goes through [`scripts/gdscript/hub_sanitize.gd`](scripts/gdscript/hub_sanitize.gd):

- **CDN fetches** — `https://cdn.blazium.app` only, with response size caps
- **External opens** — `https` only (no `javascript:` / credentials); BBCode tags allowlisted before display
- **remote_control** — bind host forced to loopback even if config is poisoned
- **SingleInstance / URIs** — only `SHOW` or `blazium:` messages; non-scheme URIs rejected

## URI scheme

| URI | Action |
|-----|--------|
| `blazium://hub` | Launch/focus Hub via CLI remote_control |
| `blazium://open?path=…` | Open the project in the editor via CLI |
| `blazium://load?path=…` | Open the project in the editor (full profile) via CLI |
| `blazium://project/<encoded-path>` | Shorthand for opening the project in the editor |
| `blazium://install?version=…` | Install editor via CLI |
| `blazium://register?path=…` | Register a local editor binary via CLI |

Flow: OS protocol handler → **`blazium-cli handle-uri`** → Hub or editor over authenticated `remote_control` (CLI launches the target if needed and waits until healthy).

### Hub remote secret (`hub_remote.json`)

CLI↔Hub auth uses port `39218` and a shared token file.

**Load order:** (1) user `%APPDATA%\blazium\hub_remote.json` / `~/.config/blazium/hub_remote.json`, then (2) machine `%ProgramData%\blazium\hub_remote.json` / `/etc/blazium/hub_remote.json`. Create only when neither is valid (runtime creates the **user** file).

**Installers always ensure the machine file** (idempotent; never rotates a valid token):

- Windows Inno (`[Code]` post-install, exit codes ignored): prefers bundled `blazium-cli hub-remote ensure` (machine `--path` under `{commonappdata}`, user via `ExecAsOriginalUser`), then falls back to Hub `--headless --ensure-hub-remote`.
- Linux postinst: Hub ensure to `/etc/blazium/hub_remote.json` (falls back to `blazium-cli hub-remote ensure --path …`); failures do not fail package configure.

Headless ensure: `BlaziumHub --headless --ensure-hub-remote [--hub-remote-path=<abs>] --quit`.

**Windows fresh vs upgrade:** Setup sets `HKLM\SOFTWARE\Blazium\Hub` → `InstallKind`=`fresh`|`upgrade`, `InstallVersion`, and on upgrade `PreviousVersion` when available. Uninstall wipes user and machine `blazium` secret dirs.

## Low-end / minimal engine

Hub is a **2D UI app**. Runtime settings use `gl_compatibility`, low processor mode, and no XR/3D effects ([`project.godot`](project.godot)).

When editing Hub in a full Blazium editor, import [`config/hub_low_end.profile`](config/hub_low_end.profile) via **Editor → Manage Feature Profiles…** to hide 3D/asset-lib clutter.

**CI builds a custom Blazium editor + `template_release`** from `blazium-games/blazium` branch `blazium_4.8` (branch tip), for Linux and Windows, x86_64 and x86_32, using the allowlist in [`ci/hub_scons.env`](ci/hub_scons.env). [`ci/BLAZIUM_REF`](ci/BLAZIUM_REF) is only the fallback when resolving the nightly editor used by Autowork:

- `modules_enabled_by_default=no` + GDScript, freetype, text_server_fb, svg, mbedtls, regex, **httpserver**, **remote_control**, **crash_reporter**, **analytics**
- Export-tool editor: baked `editor_app_id=blazium-hub` (do not pass `--app-id` / `--build-id` to the engine)
- Templates: `disable_3d=yes`, `hub_build=yes`, locked `template_app_id=blazium-hub` plus official crash/analytics URLs, `vulkan=no`, `openxr=no`, `d3d12=no`, `optimize=size`, `lto=full`
- **No** `template_debug`, tests, Mono, Luau, or JustAMCP in the shipped binary
- Runners: **`ubuntu-22.04`** and **`windows-2022`** (oldest supported GitHub-hosted images)

See [`ci/README.md`](ci/README.md) for editor vs template flag rules.

## Autowork tests

Headless Autowork suites cover Hub GDScript behavior and companion Luau scripts:

```powershell
.\tools\validate_all.ps1
# or: blazium --headless --path . -s run_tests.gd
```

CI in [`.github/workflows/cicd.yml`](.github/workflows/cicd.yml) downloads the published nightly Linux editor (Autowork + Luau) and runs the same entrypoint. Engine compiles stay on `blazium_4.8`.

## production.env (admins)

Script encryption for release exports:

1. Copy [`production.env.example`](production.env.example) → `production.env` (gitignored).
2. Set `SCRIPT_ENCRYPTION_KEY` to a 64-char hex value (`openssl rand -hex 32`).
3. Paste the **same file contents** into the GitHub Actions repository secret **`PRODUCTION_ENV`** so CI can materialize `production.env` at export time (never committed, scrubbed after jobs).

Rotate the key by updating local `production.env` and the `PRODUCTION_ENV` secret together.

## Develop

1. Open this folder in the Blazium editor (optionally apply `hub_low_end.profile`).
2. Ensure `blazium-cli` is on `PATH` (or set it in Settings).
3. Run the main scene `scenes/main.tscn`.

## Packaging & CDN

- **Windows:** Inno Setup — [`packaging/windows/blazium-hub.iss`](packaging/windows/blazium-hub.iss). Requires **admin** (machine-wide `{autopf}\Blazium`, no `/CURRENTUSER`); registers `blazium://` and finish-page options to launch Hub or visit [blazium.app](https://blazium.app). The packaged `BlaziumHub.exe` requests administrator, so every launch shows a UAC prompt and editor installs can write Program Files. `blazium-cli.exe` stays a normal process unless Hub starts it.
- **Linux:** nfpm `.deb` — [`packaging/linux/nfpm.yaml`](packaging/linux/nfpm.yaml) + `x-scheme-handler/blazium`.

CI (`.github/workflows/cicd.yml`) builds Linux and Windows installers for x86_64 and x86_32. CDN upload runs only after every required build exists, then signing, then Spaces and Cerebro.

Installers: [cdn.blazium.app](https://cdn.blazium.app) · `/dev-tools/download?tool=hub`.

## License

Licensed under the MIT License — see [LICENSE](LICENSE).
