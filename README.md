# Blazium Hub

Desktop Hub for [Blazium](https://blazium.app): browse editor builds on the public CDN, manage projects and installs through **blazium-cli**, and handle **`blazium://`** deep links.

Requires **[blazium-cli](https://github.com/blazium-games/blazium-cli)** for install/open/project mutations (shared `%APPDATA%\blazium\hub.json` / `~/.config/blazium/hub.json`).

## Features

- **Projects** — list / add / remove / open via `blazium-cli --json`
- **Editors** — CDN catalogs (`release` / `nightly`) + CLI install/uninstall
- **Settings** — CLI path, editor install path, close-to-tray (Windows), CLI upgrade check
- **System tray** (Windows) — show, recent projects, quit
- **URI scheme** `blazium://` — registered by Windows/Linux installers

## URI scheme

| URI | Action |
|-----|--------|
| `blazium://hub` | Focus Hub |
| `blazium://open?path=…` | Open/focus project via CLI |
| `blazium://load?path=…` | Load project (profile) via CLI |
| `blazium://project/<encoded-path>` | Shorthand open |
| `blazium://install?version=…` | Install editor via CLI |

Flow: OS protocol handler → Hub (single-instance) → `blazium-cli handle-uri` → running editor instance or new launch.

## Low-end / minimal engine

Hub is a **2D UI app**. Runtime settings use `gl_compatibility`, low processor mode, and no XR/3D effects ([`project.godot`](project.godot)).

When editing Hub in a full Blazium editor, import [`config/hub_low_end.profile`](config/hub_low_end.profile) via **Editor → Manage Feature Profiles…** to hide 3D/asset-lib clutter.

**CI builds a custom Blazium editor + `template_release`** from `blazium-games/blazium` at the pin in [`ci/BLAZIUM_REF`](ci/BLAZIUM_REF), using the allowlist in [`ci/hub_scons.env`](ci/hub_scons.env):

- `modules_enabled_by_default=no` + only GDScript, freetype, text_server_fb, svg, mbedtls, regex
- Templates: `disable_3d=yes`, `vulkan=no`, `openxr=no`, `d3d12=no`, `optimize=size`, `lto=full`
- **No** `template_debug`, tests, Mono, or Luau in the shipped binary
- Runners: **`ubuntu-22.04`** and **`windows-2022`** (oldest supported GitHub-hosted images)

See [`ci/README.md`](ci/README.md) for editor vs template flag rules.

## Autowork tests

Headless Autowork suites cover Hub GDScript behavior and companion Luau scripts:

```powershell
.\tools\validate_all.ps1
# or: blazium --headless --path . -s run_tests.gd
```

CI: [`.github/workflows/autowork.yml`](.github/workflows/autowork.yml) downloads a release Blazium editor (Autowork + Luau) and runs the same entrypoint.

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

- **Windows:** Inno Setup — [`packaging/windows/blazium-hub.iss`](packaging/windows/blazium-hub.iss) (`blazium://` registry).
- **Linux:** nfpm `.deb` — [`packaging/linux/nfpm.yaml`](packaging/linux/nfpm.yaml) + `x-scheme-handler/blazium`.

CI (`.github/workflows/cicd.yml`): build min engine → export with encryption → SSL.com sign (Windows) → Inno / `.deb` → Spaces `hub/{os}/{version}/` → Cerebro `POST /api/v1/tools` (`type: hub`) → `POST /api/v1/cdn/publish` `{"scope":"hub"}`.

Installers: [cdn.blazium.app](https://cdn.blazium.app) · `/dev-tools/download?tool=hub`.

## License

Licensed under the MIT License — see [LICENSE](LICENSE).
