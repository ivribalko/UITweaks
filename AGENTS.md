# UI Tweaks

Options for WoW's stock UI to reduce on-screen elements.

Aimed at [ConsolePort addon](https://www.curseforge.com/wow/addons/console-port) users, but fully usable without it.

By default, nothing is enabled, so installing the addon only adds the settings menu.

In game, go to `Options -> AddOns -> UI Tweaks` to enable features.

After changing any setting, use the **Reload** button (or run `/reload`).

## Available Settings

### Alerts

- Hide Unspent Talent Alert — Prevent the 'You have unspent talent points' reminder from popping up.

### Chat

- Auto-Hide Chat Messages — Auto-Hide chat messages after a custom duration and reveal them on mouse over.
- Fade After Seconds — Number of seconds a chat message stays before fading when the override is enabled.
- Auto-Hide Chat Tabs — Auto-Hide chat tab titles until you mouse over them.
- Set Chat Font Size — Enable a custom chat window font size for all tabs.
- Font Size — Font size to use when the override is enabled.
- Hide Chat Bubble Button — Hide the chat button with the speech bubble icon.
- Transparent Chat Background — Set the chat background alpha to zero.

### Combat

- Delay After Combat Seconds — Delay after combat seconds before restoring frames.
- Auto-Hide Damage Meter Out of Combat — Auto-Hide the built-in damage meter frame after combat until you mouse over it.
- In Raids — Collapse the objective tracker in combat while in raid instances.
- In Dungeons — Collapse the objective tracker in combat while in dungeon instances.
- Everywhere Else — Collapse the objective tracker in combat everywhere else (open world, scenarios, PvP, etc.).
- Hide Player Frame Out of Combat — Hide the player unit frame outside combat and restore it after the delay.
- Hide Target Frame Out of Combat — Hide the target unit frame outside combat and restore it after the delay.
- Replace Target Frame With Tooltip Out of Combat — Show the target tooltip when the target frame is not shown out of combat (useful for quest info like how many to kill).
- Show Tooltip For Soft (Action) Target Out of Combat — Also display the ConsolePort soft (action) target's tooltip while out of combat.

### ConsolePort

- Share ConsolePort Action Bar Settings For All Characters — Warning: This will overwrite your ConsolePort UI settings. When enabled, UI Tweaks saves your current ConsolePort action bar layout in ConsolePort's own presets as "UITweaksProfile" every time you log out, then restores that same preset automatically the next time you log in on any character. This keeps your ConsolePort action bar layout, optional bar settings, and action page logic consistent across characters without any manual export/import.

### Frames

- Auto-Hide Bags Bar — Auto-Hide the Blizzard Bags Bar until you mouse over it.
- Auto-Hide Buff Frame — Auto-Hide the default player buff frame until you mouse over it.
- Auto-Hide Stance Buttons — Auto-Hide the Blizzard stance bar/buttons until you mouse over them.
- Hide Group Loot History — Hide the group loot history frame.
- Hide Micro Menu Buttons — Hide all micro menu buttons except the Dungeon Finder eye.
- Hide Pet Frame — Hide the pet unit frame.

### Service

- Open ConsolePort Action Bar Config on Reload/Login — Open the ConsolePort action bar configuration window automatically after reload or login.
- Open This Settings Menu on Reload/Login — Re-open the UI Tweaks options panel after /reload or login (useful for development).
- Reload — Reload the interface to immediately apply changes.

## Settings Rules

Keep the Available Settings section above in sync with `UITweaks.lua`.
Each setting must use the exact in-code description string.

Keep panels and items sorted alphabetically (by display name) in both `UITweaks.lua` and this README.

Exceptions:

- Objective tracker toggles stay in this order: In Raids, In Dungeons, Everywhere Else.
- Combat: Delay After Combat Seconds stays first.
- Chat: keep checkboxes together with their respective ranges for Auto-Hide Chat Messages, Fade After Seconds and such.
- Service panel stays last.

## Dev Notes

- Addon files live in repo root: `UITweaks.toc`, `UITweaks.lua`, `Libs/`.
- Add new Lua files in repo root and list them in `UITweaks.toc`.
- No build step. Install by copying/symlinking the `UITweaks` folder into WoW AddOns.
- Example install (macOS): `cp -R UITweaks /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/`
- Use `/reload` after code or setting changes.
- Debug helpers: `/console scriptErrors 1`, `/eventtrace`, `/fstack`.
