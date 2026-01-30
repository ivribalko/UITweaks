# Repository Guidelines

## Project Structure & Module Organization

The playable addon lives entirely under `UITweaks/`. `UITweaks/UITweaks.toc` specifies load order, `UITweaks/UITweaks.lua` defines the AceAddon entry point and option tables, and `UITweaks/Libs/` vendors the full Ace3 bundle. High-level layout:

```text
UITweaks/
  UITweaks.toc
  UITweaks.lua
  Libs/ (Ace3 + dependencies)
```

Add new Lua modules inside `UITweaks/`, list them in the `.toc`, and keep tooling scripts outside the addon folder so they are not shipped to players.

## Addon Stack & References

This repository targets World of Warcraft retail clients and relies on Ace3 for console commands, events, configuration dialogs, and saved variables. Context7 MCP hosts the authoritative docs at `wowuidev/ace3`; contributors must consult that set whenever they touch Ace libraries, widgets, or mixins so implementations match upstream expectations. Core gameplay tweaks (chat fade/font overrides, buff-frame collapse, damage-meter delay hiding, bag-bar and stance-button toggles, hide-chat-tabs option, optional target tooltip, and the "show options on reload" debug helper) all live in `UITweaks.lua`, so changes to those systems start by editing that file.

## Build, Test, and Development Commands

There is no build step. Copy or symlink `UITweaks/` into your WoW AddOns directory (macOS example: `cp -R UITweaks /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/`). Reload the UI with `/reload` or relaunch the client to pick up Lua changes. Use `/eventtrace` and `/fstack` (frame stack inspector) plus temporary prints when debugging hooks like `BuffFrame.CollapseAndExpandButton` or `DamageMeter`, then package releases with `zip -r UITweaks.zip UITweaks` to preserve directory structure.

## Coding Style & Naming Conventions

Use four-space indentation, `local` scoping, and double-quoted strings. Keep Ace3 option tables declarative, grouped by feature, and hold defaults in the shared `defaults.profile` table. Prefix frames, slash commands, and SavedVariables with `UITweaks` to avoid collisions. Do not modify vendored libraries; extend or override behavior in addon files instead.

## UI Option Behavior

When implementing option toggles, use only `if enabled then ... end` flows. Avoid `else` branches that restore or change behavior when the option is disabled.

## Debugging Tip

Use `/console scriptErrors 1` to surface Lua errors while testing.

## Testing Guidelines

Automated tests are not configured, so rely on in-game manual verification. Toggle options under Interface → AddOns → UI Tweaks, re-login or `/reload`, and observe chat output. Document scenarios, client build, and observed results in the PR description. Temporary debug prints are acceptable if gated and removed before release.

## Commit & Pull Request Guidelines

Write imperative commit subjects (e.g., "Add chat fade override") and keep each commit focused. Pull requests should include the motivation or linked issue, summary of user-facing changes, manual test notes, screenshots/GIFs for UI tweaks, and callouts for SavedVariables or dependency updates.

## Security & Configuration Tips

Never commit WTF/SavedVariables or account data. Treat `Libs/` as vendored: update from upstream Ace3 releases and cite the source version in the PR. When adding options, seed sane defaults in AceDB before reading them to prevent nil access during login.

## Settings Reference

This section must be kept in sync with `UITweaks.lua`. Every setting listed here must use the exact in-code description string. Updating settings in code without updating this section is not allowed.

### Chat

- Chat Message Fade Override — Enable a custom duration for how long chat messages remain visible before fading.
- Fade After Seconds — Number of seconds a chat message stays before fading when the override is enabled.
- Chat Font Size Override — Enable a custom chat window font size for all tabs.
- Font Size — Font size to use when the override is enabled.
- Hide Chat Tabs — Hide chat tab titles while leaving the windows visible.
- Hide Chat Bubble Button — Hide the chat button with the speech bubble icon.

### Alerts

- Hide Unspent Talent Alert — Prevent the 'You have unspent talent points' reminder from popping up.

### Combat

- Delay Seconds — Delay before restoring frames after combat ends.
- Hide Player Frame Out of Combat — Hide the player unit frame outside combat and restore it after the shared delay.
- Hide Target Frame Out of Combat — Hide the target unit frame outside combat and restore it after the shared delay.
- Hide Damage Meter Out of Combat — Hide the built-in damage meter frame after you leave combat (shares the delay with the player frame/objective tracker).
- Show Tooltip For Selected Target Out of Combat — Automatically display the currently selected target's tooltip while out of combat.
- Show Tooltip For Soft (Action) Target Out of Combat — Also display the ConsolePort soft (action) target's tooltip while out of combat.
- Collapse In Combat — Collapse the quest/objective tracker during combat and re-expand it after combat ends (shares the delay with the damage meter/player frame).
- Only In Dungeons/Raids — Only collapse the objective tracker while in dungeon or raid instances.

### Frames

- Hide Buff Frame — Hide the default player buff frame UI.
- Hide Stance Buttons — Hide the Blizzard stance bar/buttons when you don't need them.
- Hide Bags Bar — Hide the entire Blizzard Bags Bar next to the action bars.
- Hide Micro Menu Buttons — Hide all micro menu buttons except the Dungeon Finder eye.

### ConsolePort

- Share ConsolePort Action Bar Settings For All Characters — Warning: This will overwrite your ConsolePort UI settings. When enabled, UI Tweaks saves your current ConsolePort action bar layout in ConsolePort's own presets as "UITweaksProfile" every time you log out, then restores that same preset automatically the next time you log in on any character. This keeps your ConsolePort action bar layout, optional bar settings, and action page logic consistent across characters without any manual export/import.

### Service

- Open This Settings Menu on Reload/Login — Re-open the UI Tweaks options panel after /reload or login (useful for development).
- Open ConsolePort Action Bar Config on Reload/Login — Open the ConsolePort action bar configuration window automatically after reload or login.
- Reload — Reload the interface to immediately apply changes.
