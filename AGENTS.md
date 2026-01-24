# Repository Guidelines

## Project Structure & Module Organization
The playable addon lives entirely under `UITweaks/`. `UITweaks/UITweaks.toc` specifies load order, `UITweaks/UITweaks.lua` defines the AceAddon entry point and option tables, and `UITweaks/Libs/` vendors the full Ace3 bundle. High-level layout:

```
UITweaks/
  UITweaks.toc
  UITweaks.lua
  Libs/ (Ace3 + dependencies)
```

Add new Lua modules inside `UITweaks/`, list them in the `.toc`, and keep tooling scripts outside the addon folder so they are not shipped to players.

## Addon Stack & References
This repository targets World of Warcraft retail clients and relies on Ace3 for console commands, events, configuration dialogs, and saved variables. Context7 MCP hosts the authoritative docs at `wowuidev/ace3`; contributors must consult that set whenever they touch Ace libraries, widgets, or mixins so implementations match upstream expectations.

## Build, Test, and Development Commands
There is no build step. Copy or symlink `UITweaks/` into your WoW AddOns directory (macOS example: `cp -R UITweaks /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/`). Reload the UI with `/reload` or relaunch the client to pick up Lua changes. Package releases with `zip -r UITweaks.zip UITweaks` to preserve the directory structure.

## Coding Style & Naming Conventions
Use four-space indentation, `local` scoping, and double-quoted strings. Keep Ace3 option tables declarative, grouped by feature, and hold defaults in the shared `defaults.profile` table. Prefix frames, slash commands, and SavedVariables with `UITweaks` to avoid collisions. Do not modify vendored libraries; extend or override behavior in addon files instead.

## Testing Guidelines
Automated tests are not configured, so rely on in-game manual verification. Toggle options under Interface → AddOns → UI Tweaks, relog or `/reload`, and observe chat output. Document scenarios, client build, and observed results in the PR description. Temporary debug prints are acceptable if gated and removed before release.

## Commit & Pull Request Guidelines
Write imperative commit subjects (e.g., "Add login greeting toggle") and keep each commit focused. Pull requests should include the motivation or linked issue, summary of user-facing changes, manual test notes, screenshots/GIFs for UI tweaks, and callouts for SavedVariables or dependency updates.

## Security & Configuration Tips
Never commit WTF/SavedVariables or account data. Treat `Libs/` as vendored: update from upstream Ace3 releases and cite the source version in the PR. When adding options, seed sane defaults in AceDB before reading them to prevent nil access during login.
