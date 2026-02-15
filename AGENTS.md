# UI Tweaks

Options for WoW's stock UI to reduce on-screen elements.

Aimed at [ConsolePort addon](https://www.curseforge.com/wow/addons/console-port) users, but fully usable without it.

By default, nothing is enabled, so installing the addon only adds the settings menu.

In game, go to `Options -> AddOns -> UI Tweaks` to enable features.

After changing any setting, use the **Reload** button (or run `/reload`).

Action Button Auras are inspired by [CDMButtonAuras addon](https://www.curseforge.com/wow/addons/cdmbuttonauras).

## Available Settings

### Action Bars

- Hide Blizzard Cooldown Viewers — Move Blizzard's Cooldown Viewer elements off-screen and shrink them to near-zero scale (Buff Bar, Buff Icon, Essential, Utility).
- Share Skyriding Action Bar Skills For All Characters — Warning: This will overwrite your Skyriding action bar skills layout. When enabled, UI Tweaks saves the Skyriding action bar (bonus bar 5) after you dismount (actual mount, not shapeshift), then restores that layout on login for any character. It will not overwrite slots using empty or unavailable skills.
- Show Action Button Aura Timers — Show buffs and debuffs highlight and remaining duration on action buttons. Requires Blizzard Cooldown Manager: Options -> Gameplay Enhancements -> Enable Cooldown Manager. In Cooldown Manager, move abilities from 'Not Displayed' to 'Tracked Buffs' or 'Tracked Bars' then close the window to save it. Cooldown Viewer auras work in and out of combat. Additional highlights from untracked player buffs and items on the action bar only reapply out of combat.
- Open Advanced Cooldown Settings — Open the Cooldown Viewer settings window on Buffs tab.

### Chat

- Auto-Hide Chat Messages — Auto-Hide chat messages after a custom duration and reveal them on mouse over.
- Fade After Seconds — Number of seconds a chat message stays before fading when the override is enabled.
- Auto-Hide Chat Tabs — Auto-Hide chat tab titles until you mouse over them.
- Set Chat Font Size — Enable a custom chat window font size for all tabs.
- Font Size — Font size to use when the override is enabled.
- Hide Chat Bubble Button — Hide the chat button with the speech bubble icon.
- Transparent Chat Background — Set the chat background alpha to zero.

### Combat

- Delay Restoring Out of Combat — Delay before restoring frames after combat end for set seconds.
- Auto-Hide Damage Meter Out of Combat — Auto-Hide the built-in damage meter frame after combat until you mouse over it.
- In Raids — Collapse the objective tracker in combat while in raid instances.
- In Dungeons — Collapse the objective tracker in combat while in dungeon instances.
- Everywhere Else — Collapse the objective tracker in combat everywhere else (open world, scenarios, PvP, etc.).
- Hide Player Frame Out of Combat — Hide the player unit frame outside combat.
- Hide Target Frame Out of Combat — Hide the target unit frame outside combat.
- Replace Target Frame With Tooltip Out of Combat — Show the target tooltip instead of target frame out of combat (useful to check if target is related to any active quests).
- Show Tooltip For Soft (Action) Target Out of Combat — Also display the ConsolePort soft (action) target's tooltip while out of combat.

### ConsolePort

- Hide ConsolePort 'New Ability Available!' Frame — Hide ConsolePortTempAbilityFrame, e.g., Dungeon Assistance ability alert in Follower Dungeons.
- Share ConsolePort Action Bar Settings For All Characters — Warning: This will overwrite your ConsolePort UI settings. When enabled, UI Tweaks saves your current ConsolePort action bar layout in ConsolePort's own presets as "UITweaksProfile" every time you log out, then restores that same preset automatically the next time you log in on any character. This keeps your ConsolePort action bar layout, optional bar settings, and action page logic consistent across characters without any manual export/import.
- Open ConsolePort Designer — Open the ConsolePort action bar configuration window.

### Other

- Auto-Hide Bags Bar — Auto-Hide the Blizzard Bags Bar until you mouse over it.
- Auto-Hide Buff Frame — Auto-Hide the Blizzard player buff frame until you mouse over it.
- Auto-Hide Stance Bar — Auto-Hide the Blizzard stance bar until you mouse over it.
- Hide Group Loot History — Hide the group loot history frame.
- Hide Help Tips — Hide help tooltips like 'You have unspent talent points' and 'You can drag this to your action bar'.
- Hide Micro Menu Buttons — Hide all micro menu buttons except the Dungeon Finder eye.

## Settings Rules

Keep the Available Settings section above in sync with `UITweaks.Options.lua`.
Each setting must use the exact in-code description string.

Keep panels and items sorted alphabetically (by display name) in both `UITweaks.Options.lua` and this README.

Exceptions:

- Objective tracker toggles stay in this order: In Raids, In Dungeons, Everywhere Else.
- Combat: Delay After Combat Seconds stays first.
- Chat: keep checkboxes together with their respective ranges for Auto-Hide Chat Messages, Fade After Seconds and such.
- Action Bars: Open Advanced Cooldown Settings stays last.
- Service panel stays last.

## Dev Notes

- Addon files live in the repository root.
- Main addon files are split as: `UITweaks.lua` (core), `UITweaks.Options.lua` (defaults + options), `UITweaks.Auras.lua` (action button aura logic).
- Add new Lua files in the repository root and list them in `UITweaks.toc`.
- No build step. Install by copying/symlinking the `UITweaks` folder into WoW AddOns.
- Example install (macOS): `ln -s "$PWD" /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/`
- Use `/reload` after code or setting changes.
- Do not implement immediate “restore defaults on disable” behavior; require `/reload` to revert to stock UI defaults.
- Service panel is alpha-only and intentionally omitted from this README.
- `refs/` contains addons and other files used strictly as references. Do not use or read anything in `refs/` unless explicitly instructed.
- Debug helpers: `/console scriptErrors 1`, `/eventtrace`, `/fstack`.
