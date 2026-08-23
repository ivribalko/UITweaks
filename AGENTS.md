# Stock UI Tweaks

Options for WoW's stock UI to reduce on-screen elements.

Aimed at [ConsolePort addon](https://www.curseforge.com/wow/addons/console-port) users, but fully usable without it.

Recommended to be used together with [EnhanceQoL addon](https://www.curseforge.com/wow/addons/eqol).

By default, nothing is enabled, so installing the addon only adds the settings menu.

In game, go to `Options -> AddOns -> Stock UI Tweaks` to enable features.

After changing any setting, use the **Reload** button (or run `/reload`).

## Available Settings

### Chat

- Auto-Hide Chat Tabs — Auto-Hide chat tab titles until you mouse over them. Set Options -> Social -> New Whispers: In-line to prevent new tabs from appearing.
- Hide All Speech Bubbles — Hide all native world-space speech bubbles from players and NPCs. Separate Talking Head, gossip, quest, and raid warning UI remains visible.
- Hide Chat Bubble Button — Auto-hide the chat button with the speech bubble icon until you mouse over the chat buttons area.
- Hide Chat Channels Button — Auto-hide the chat button that opens the channel list until you mouse over the chat buttons area.
- Hide Social Button — Auto-hide the social button next to the chat frame until you mouse over the chat buttons area.
- Set Chat Font Size — Enable a custom chat window font size for all tabs.
- Font Size — Font size to use when the override is enabled.
- Transparent Chat Background — Set the chat background alpha to zero.

### Combat

- In Raids — Fade out the objective tracker in combat while in raid instances.
- In Dungeons — Fade out the objective tracker in combat while in dungeon instances.
- Everywhere Else — Fade out the objective tracker in combat everywhere else (open world, scenarios, PvP, etc.).
- Hide Target Frame Buffs and Debuffs — Hide all buffs and debuffs from the target frame.
- Player and Target Frame Opacity In Combat — Set the player and target unit frame opacity in combat from 0% (invisible) to 100% (fully opaque).
- Player and Target Frame Opacity Out of Combat — Set the player and target unit frame opacity outside combat from 0% (invisible) to 100% (fully opaque).

### ConsolePort

- Add Leave Instance Group To ConsolePort Menu Ring — Add a separate Leave Instance Group button next to ConsolePort's dungeon teleport button in the menu ring. The button is hidden while you are not in a party or when ConsolePort's regular Leave Party action is already shown.
- Add Mythic+ Finder To ConsolePort Menu Ring — Add a Mythic+ Finder button next to ConsolePort's Group Finder button in the menu ring. It opens the Premade Groups dungeon search directly.
- Add Sound Toggle To ConsolePort Menu Ring — Add a Sound button to ConsolePort's menu ring that toggles Settings -> Game -> Audio -> Enable Sound and shows whether sound is enabled or disabled.
- Disable Immersion Dialog List Item Scaling — Prevent Immersion's active dialogue list items from growing when hovered or selected.
- Fix Dropdowns For ConsolePort — Allow ConsolePort's controller X button to open modern dropdown menus throughout the UI, such as the Raid Finder raid selector and Premade Groups filter.
- Focus Mailbox Open All Button — Focus the ConsolePort controller cursor on the mailbox's Open All button when opening the mailbox.
- Hide ConsolePort 'New Ability Available!' Frame — Hide ConsolePortTempAbilityFrame, e.g., Dungeon Assistance ability alert in Follower Dungeons.
- Overlay Cooldown Manager Icons On ConsolePort Action Bar — Overlay Blizzard Cooldown Manager tracked buff, essential cooldown, and utility cooldown icons on matching ConsolePort action bar buttons at the same position and size, replacing the original action artwork while preserving ConsolePort button frames, gamepad icons, and matching button opacity. Updates when ConsolePort toggle keys change the action shown on a button.
- Share ConsolePort Action Bar Settings For All Characters — Warning: This will overwrite your ConsolePort UI settings. When enabled, Stock UI Tweaks saves your current ConsolePort action bar layout in ConsolePort's own presets as "UITweaksProfile" every time you log out, then restores that same preset automatically the next time you log in on any character. This keeps your ConsolePort action bar layout, optional bar settings, and action page logic consistent across characters without any manual export/import.
- Use Circle To Cancel Immersion Dialogues — Use Circle to cancel or close Immersion dialogue and Triangle to inspect items or back out of item inspection when using ConsolePort.
- Open ConsolePort Designer — Open the ConsolePort action bar configuration window.
- Open Advanced Cooldown Settings — Open Blizzard's Advanced Cooldown Settings on the Auras tab.

### Other

- Add Quest Prev/Next/Abandon Macros — Pressing this button creates or updates macros named Quest Abandon, Quest Next, and Quest Prev, then opens the Macro menu. Quest Abandon runs /uitabandonquest and opens the standard abandon confirmation for the currently selected tracked quest. Quest Next runs /uitnextquest and selects the next tracked quest (or the first if none is selected). Quest Prev runs /uitprevquest and selects the previous tracked quest (or the last if none is selected).
- Adjust Minimap Zoom Based On Player Speed — Automatically zoom the minimap in while stationary, use one zoom level while moving or in combat, and fully zoom it out while flying.
- Always Show Quest Marker Distance — Always show the built-in quest marker distance, even when not facing the objective.
- Auto-Hide Stance Bar — Auto-Hide the Blizzard stance bar until you mouse over it.
- Hide Compact Raid Frame Manager — Hide the compact raid frame manager.
- Hide Group Loot History — Hide the group loot history frame.
- Hide Help Tips — Hide help tooltips like 'You have unspent talent points' and 'You can drag this to your action bar'.
- Hide Totem Frame — Hide the totem frame, including warlock pets.
- Highlight Active Consumables In Inventory — Highlight inventory consumables with a green frame and remaining buff time when their player aura or weapon enchant is active. Supports flasks, food, oils, and other consumables that apply a helpful aura or temporary weapon enchant. If a Well Fed buff is active, all food items are highlighted with that buff's remaining time. Cases where a consumable applies an aura with a different name than the item spell are not supported (except Well Fed food). Does not update during combat.
- Party and Raid Frame Scale — Scale Blizzard's party and raid frame containers from 50% to 100%. Set this to 100% and reload to use Blizzard's Edit Mode sizes.
- Share Skyriding Action Bar Skills For All Characters — Warning: This will overwrite your Skyriding action bar skills layout. When enabled, Stock UI Tweaks saves the Skyriding action bar (bonus bar 5) after you dismount (actual mount, not shapeshift), then restores that layout on login for any character. It will not overwrite slots using empty or unavailable skills.

## Settings Rules

Keep the Available Settings section above in sync with `UITweaksOptions.lua`.
Each setting must use the exact in-code description string.

Keep panels and items sorted alphabetically (by display name) in both `UITweaksOptions.lua` and this README.

Exceptions:

- Objective tracker toggles stay in this order: In Raids, In Dungeons, Everywhere Else.
- Chat: keep checkboxes together with their respective ranges, such as Set Chat Font Size and Font Size.
- Explanatory notes stay directly below their related checkboxes.
- ConsolePort: Open ConsolePort Designer stays after the toggles, and Open Advanced Cooldown Settings stays last.
- Debug panel stays last.

## Dev Notes

- Addon files live in the repository root.
- Main addon files are split as: `UITweaks.lua` (core), `UITweaksOptions.lua` (defaults + options), `UITweaksConsumables.lua` (inventory consumable highlights), `UITweaksCooldownOverlay.lua` (Cooldown Manager and ConsolePort action button overlay), `UITweaksImmersion.lua` (Immersion controller compatibility), `UITweaksConsolePortMenu.lua` (ConsolePort menu ring and dropdown compatibility), `UITweaksDebug.lua` (debug tools/UI).
- Add new Lua files in the repository root and list them in `UITweaks.toc`.
- No build step. Install by copying/symlinking the `UITweaks` folder into WoW AddOns.
- Example install (macOS): `ln -s "$PWD" /Applications/World\ of\ Warcraft/_retail_/Interface/AddOns/`
- Use `/reload` after code or setting changes.
- Assume `self.db`, `self.debug`, and `self.options` always exist; do not add nil/existence guards for them.
- Prefer frame `OnEnter`/`OnLeave` hooks or other event-driven updates over high-frequency `C_Timer.NewTicker` polling for hover-driven UI visibility; repeated scans in 0.1s tickers can cause large CPU spikes.
- Do not implement immediate “restore defaults on disable” behavior; require `/reload` to revert to stock UI defaults.
- Debug panel is alpha-only and intentionally omitted from this README.
- `AddOns/` contains addons and other files used strictly as references. Do not use or read anything in `AddOns/` unless explicitly instructed.
- When changing this addon, use other addons in the same parent folder as reference sources when useful, but never edit them.
- Check WoW UI source at [https://github.com/Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) if Blizzard UI behavior or implementation details need verification.
- Debug helpers: `/console scriptErrors 1`, `/eventtrace`, `/fstack`.
