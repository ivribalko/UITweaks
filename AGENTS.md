# Stock UI Tweaks

Options for WoW's stock UI to reduce on-screen elements.

Aimed at [ConsolePort addon](https://www.curseforge.com/wow/addons/console-port) users, but fully usable without it.

Recommended to be used together with [EnhanceQoL](https://www.curseforge.com/wow/addons/eqol).

By default, nothing is enabled, so installing the addon only adds the settings menu.

In game, go to `Options -> AddOns -> Stock UI Tweaks` to enable features.

After changing any setting, use the **Reload** button (or run `/reload`).

## Available Settings

### Action Bars

- Share Skyriding Action Bar Skills For All Characters — Warning: This will overwrite your Skyriding action bar skills layout. When enabled, Stock UI Tweaks saves the Skyriding action bar (bonus bar 5) after you dismount (actual mount, not shapeshift), then restores that layout on login for any character. It will not overwrite slots using empty or unavailable skills.

### Chat

- Auto-Hide Chat Tabs — Auto-Hide chat tab titles until you mouse over them. Set Options -> Social -> New Whispers: In-line to prevent new tabs from appearing.
- Hide Chat Bubble Button — Auto-hide the chat button with the speech bubble icon until you mouse over the chat buttons area.
- Hide Chat Channels Button — Auto-hide the chat button that opens the channel list until you mouse over the chat buttons area.
- Hide Social Button — Auto-hide the social button next to the chat frame until you mouse over the chat buttons area.
- Set Chat Font Size — Enable a custom chat window font size for all tabs.
- Font Size — Font size to use when the override is enabled.
- Transparent Chat Background — Set the chat background alpha to zero.

### Combat

- Delay Restoring Out of Combat — Delay before restoring frames after combat end for set seconds.
- Auto-Hide Damage Meter Out of Combat — Auto-Hide the built-in damage meter frame after combat until you mouse over it.
- In Raids — Collapse the objective tracker in combat while in raid instances.
- In Dungeons — Collapse the objective tracker in combat while in dungeon instances.
- Everywhere Else — Collapse the objective tracker in combat everywhere else (open world, scenarios, PvP, etc.).
- Hide Player Frame Out of Combat — Hide the player unit frame outside combat.
- Hide Target Frame Out of Combat — Hide the target unit frame outside combat.
- Show Tooltip For Soft (Action) Target Out of Combat — Display the ConsolePort soft (action) target's tooltip while out of combat. Useful to check if the target is related to any active quests.

### ConsolePort

- Hide ConsolePort 'New Ability Available!' Frame — Hide ConsolePortTempAbilityFrame, e.g., Dungeon Assistance ability alert in Follower Dungeons.
- Share ConsolePort Action Bar Settings For All Characters — Warning: This will overwrite your ConsolePort UI settings. When enabled, Stock UI Tweaks saves your current ConsolePort action bar layout in ConsolePort's own presets as "UITweaksProfile" every time you log out, then restores that same preset automatically the next time you log in on any character. This keeps your ConsolePort action bar layout, optional bar settings, and action page logic consistent across characters without any manual export/import.
- Open ConsolePort Designer — Open the ConsolePort action bar configuration window.

### Other

- Add Quest Prev/Next Macros — Pressing this button creates or updates macros named Quest Next and Quest Prev, then opens the Macro menu. Quest Next runs /uitnextquest and selects the next tracked quest (or the first if none is selected). Quest Prev runs /uitprevquest and selects the previous tracked quest (or the last if none is selected).
- Always Show Quest Marker Distance — Always show the built-in quest marker distance, even when not facing the objective.
- Auto-Hide Bags Bar — Auto-Hide the Blizzard Bags Bar until you mouse over it.
- Auto-Hide Buff Frame — Auto-Hide the Blizzard player buff frame until you mouse over it.
- Auto-Hide Stance Bar — Auto-Hide the Blizzard stance bar until you mouse over it.
- Hide Group Loot History — Hide the group loot history frame.
- Hide Help Tips — Hide help tooltips like 'You have unspent talent points' and 'You can drag this to your action bar'.
- Hide Minimap Addon Icons — Hide addon minimap icons, except the AddOn Compartment button.
- Hide Micro Menu Buttons — Hide all micro menu buttons except the Dungeon Finder eye.
- Hide Totem Frame — Hide the totem frame, including warlock pets.
- Highlight Active Consumables In Inventory — Highlight inventory consumables with a green frame and remaining buff time when their player aura or weapon enchant is active. Supports flasks, food, oils, and other consumables that apply a helpful aura or temporary weapon enchant. If a Well Fed buff is active, all food items are highlighted with that buff's remaining time. Cases where a consumable applies an aura with a different name than the item spell are not supported (except Well Fed food). Does not update during combat.

## Settings Rules

Keep the Available Settings section above in sync with `UITweaksOptions.lua`.
Each setting must use the exact in-code description string.

Keep panels and items sorted alphabetically (by display name) in both `UITweaksOptions.lua` and this README.

Exceptions:

- Objective tracker toggles stay in this order: In Raids, In Dungeons, Everywhere Else.
- Combat: Delay After Combat Seconds stays first.
- Chat: keep checkboxes together with their respective ranges, such as Set Chat Font Size and Font Size.
- Debug panel stays last.

## Dev Notes

- Addon files live in the repository root.
- Main addon files are split as: `UITweaks.lua` (core), `UITweaksOptions.lua` (defaults + options), `UITweaksConsumables.lua` (inventory consumable highlights), `UITweaksDebug.lua` (debug tools/UI).
- Add new Lua files in the repository root and list them in `UITweaks.toc`.
- No build step. Install by copying/symlinking the `UITweaks` folder into WoW AddOns.
- Example install (macOS): `ln -s "$PWD" /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/`
- Use `/reload` after code or setting changes.
- Assume `self.db`, `self.debug`, and `self.options` always exist; do not add nil/existence guards for them.
- Do not implement immediate “restore defaults on disable” behavior; require `/reload` to revert to stock UI defaults.
- Debug panel is alpha-only and intentionally omitted from this README.
- `AddOns/` contains addons and other files used strictly as references. Do not use or read anything in `AddOns/` unless explicitly instructed.
- Check WoW UI source at [https://github.com/Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) if Blizzard UI behavior or implementation details need verification.
- Debug helpers: `/console scriptErrors 1`, `/eventtrace`, `/fstack`.
