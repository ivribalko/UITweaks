# Architecture

Stock UI Tweaks is an Ace3 addon organized around a small core and focused feature modules.

## Folder Layout

- `UITweaks.lua` owns addon lifecycle events, stock UI behavior, and the minimap settings shortcut.
- `UITweaksOptions.lua` defines saved-variable defaults and the AceConfig settings panels.
- `UITweaksConsumables.lua` detects active consumables and updates inventory highlights.
- `UITweaksCooldownOverlay.lua` places Blizzard Cooldown Manager icons over matching ConsolePort action buttons.
- `UITweaksImmersion.lua` applies the optional Immersion and ConsolePort controller compatibility layer.
- `UITweaksConsolePortBags.lua` closes all open inventory bags from ConsolePort's cancel action.
- `UITweaksConsolePortMovement.lua` prevents ConsolePort from overriding its camera-facing preference during spell casts.
- `UITweaksConsolePortMenu.lua` adds optional actions to ConsolePort's menu ring and applies controller compatibility to modern dropdowns.
- `UITweaksConsolePortItemMenu.lua` adds optional commands to ConsolePort's inventory item options.
- `UITweaksDebug.lua` contains alpha-only diagnostics and debugging UI.
- `Libs/` contains embedded Ace3 dependencies.
- `Textures/` and the root icon files contain addon artwork.

## Component Interactions

AceAddon initializes the shared database, then passes the addon instance to the options, consumables, Cooldown Manager overlay, Immersion compatibility, and debug modules. Settings are stored in the AceDB profile. Lifecycle and game events enter through `UITweaks.lua`, which delegates specialized work to the relevant module.

The core registers ConsolePort's enabled crosshair with WoW's secure visibility state driver when the combat-only option is enabled. The `[combat] show; hide` condition controls visibility directly from the game's combat state.

The Cooldown Manager overlay module matches Blizzard cooldown entries to ConsolePort action buttons by spell ID. It keeps the native Blizzard item frames and their update behavior, but anchors them to the matching ConsolePort buttons through separate visibility containers so the original Cooldown Manager visibility settings still apply. Known tracked auras whose spell IDs differ from their actions, including Demonic Core, Infernal Bolt, and Ruination, are linked to their base, intermediate, and replacement action spell IDs, following active override chains recursively. BuffIcon items are processed before cooldown items so active ticking buffs take priority when both can match the same button. Matched buttons keep their secure input frame, persistent ConsolePort frame texture, native spell-activation glows, and gamepad hotkeys while their original action artwork is hidden, and each native item samples the button's effective opacity during existing overlay updates. An optional setting hides native countdown numbers and applies the Essential Cooldown yellow swipe color while matched items display active buffs, then restores the numbers when those items display cooldowns. Active-buff appearance is reapplied synchronously after native item refreshes, while structural rematching remains deferred.

The Immersion compatibility module activates only when its setting is enabled and both Immersion and ConsolePort are loaded. It wraps Immersion's controller command and hint methods in memory, leaving Immersion's installed files unchanged. A UI reload removes the wrappers; UITweaks reapplies them only if the setting remains enabled.

The ConsolePort bags module wraps ConsolePort's cancel-handler lookup for nodes contained by Blizzard inventory bag frames. ConsolePort invokes the replacement while its cursor is anywhere within an inventory bag, closing every open bag without changing cancel behavior on other UI frames.

The ConsolePort movement module suppresses ConsolePort's temporary cast, channel, and empowered-cast handlers that force character facing to follow the camera. Vehicle-specific camera behavior remains unchanged.

The ConsolePort inventory item module extends ConsolePort's Triangle options in memory. For recognized weapon oils, it adds a secure command that uses the selected bag item and applies it to the main-hand equipment slot.

The minimap shortcut registers through LibDataBroker and LibDBIcon when another enabled addon provides those libraries, allowing minimap managers to discover it through standard callbacks. A standalone button provides the same shortcut when those libraries are unavailable.
