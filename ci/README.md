# Hub engine CI flags

| File | Purpose |
|------|---------|
| `BLAZIUM_REF` | Pinned `blazium-games/blazium` commit/tag for reproducible builds |
| `hub_scons.env` | Minimal SCons allowlist (`HUB_SCONS_COMMON` + template-only `HUB_SCONS_TEMPLATE`) |

## Editor vs template

| | Editor (export tool) | `template_release` |
|--|----------------------|--------------------|
| `HUB_SCONS_COMMON` | yes | yes |
| `disable_3d=yes` | **no** (engine forbids) | **yes** |
| `disable_advanced_gui` | no | no (Hub needs FileDialog / PopupMenu / OptionButton / splits) |

Only `template_release` is built (no `template_debug`, no `tests=yes`).

Use `lto=full` (not `lto=thin`) so GHA MSVC/GCC builds work without LLVM.
