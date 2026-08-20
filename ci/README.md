# Hub engine CI flags

| File | Purpose |
|------|---------|
| `BLAZIUM_REF` | Pinned `blazium-games/blazium` commit/tag for reproducible builds |
| `hub_scons.env` | Minimal SCons allowlist (`HUB_SCONS_COMMON` + `HUB_SCONS_EDITOR` + template-only `HUB_SCONS_TEMPLATE`) |

## Editor vs template

| | Editor (export tool) | `template_release` |
|--|----------------------|--------------------|
| `HUB_SCONS_COMMON` | yes | yes |
| `HUB_SCONS_EDITOR` | yes (`editor_*` bake) | no |
| `HUB_SCONS_TEMPLATE` | no | yes (`template_*` lock) |
| `disable_3d=yes` | **no** (engine forbids) | **yes** |
| `disable_advanced_gui` | no | no (Hub needs FileDialog / PopupMenu / OptionButton / splits) |

Editor identity is SCons-baked (`editor_app_id=blazium-hub`). Do not pass `--app-id` / `--build-id` to the engine. The shipped Hub template bakes `template_app_id=blazium-hub` plus official crash/analytics URLs so `project.godot` cannot spoof identity at runtime.

Only `template_release` is built (no `template_debug`, no `tests=yes`).

Use `lto=full` (not `lto=thin`) so GHA MSVC/GCC builds work without LLVM.
