# Repository Guidelines

## Project Structure & Module Organization

Noctalia is a QML desktop shell run by Noctalia Quickshell. `shell.qml` is the
entry point. Keep shared QML singletons in `Commons/`, helpers in `Helpers/`,
and service integrations in `Services/`. UI features live under `Modules/`
(bar, panels, lock screen, notifications, widgets); reusable controls belong in
`Widgets/`. Static data, translations, templates, fonts, and images are in
`Assets/`. Python and Bash utilities are under `Scripts/`; Nix packaging and
development configuration are under `nix/`, `flake.nix`, and `shell.nix`.

## Build, Test, and Development Commands

- `qs -p .` runs this checkout locally. Use it for a visual smoke test after
  QML changes; avoid launching a second instance of the running shell.
- `./Scripts/dev/qmlfmt.sh` formats every `*.qml` file using `qmlformat`.
  Install a Qt 6 declarative tools package if the command reports it missing.
- `nix develop` opens the development shell; `nix build` builds the default
  Nix package.
- `./Scripts/dev/shaders-compile.sh` regenerates compiled shader assets after
  modifying files in `Shaders/frag/`.

There is no separate automated test suite in this revision. At minimum, format
the touched QML, start the shell, and exercise the affected UI and IPC path.

## Coding Style & Naming Conventions

Use two-space indentation in QML, as enforced by `qmlfmt.sh`; keep lines within
its 360-column limit. Use PascalCase filenames and component names
(`ControlCenter.qml`), camelCase properties/functions, and clear module import
paths such as `qs.Modules.Bar`. Prefer existing `Commons` services and style
tokens over duplicating state or hard-coded colors. Run the formatter before
committing; Lefthook formats QML and rebuilds `Assets/settings-search-index.json`
on pre-commit.

## Commit & Pull Request Guidelines

Recent history uses concise imperative subjects with optional scopes, e.g.
`compositor: Update Hyprland functions` or `chore(flake): update flake.lock`.
Keep each commit focused. PRs should describe visible behavior, link an issue
when applicable, and include screenshots or recordings for UI changes. Mention
any required settings migration, dependency, or shader regeneration.

## Configuration & Security

Do not commit personal settings, tokens, or machine-specific paths. Treat
commands executed from QML and scripts as security-sensitive; validate external
input and preserve the existing asynchronous-service patterns.
