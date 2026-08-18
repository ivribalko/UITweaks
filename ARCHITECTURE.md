# Architecture

Stock UI Tweaks is an Ace3 addon organized around a small core and focused feature modules.

## Folder Layout

- `UITweaks.lua` owns addon lifecycle events, stock UI behavior, and the minimap settings shortcut.
- `UITweaksOptions.lua` defines saved-variable defaults and the AceConfig settings panels.
- `UITweaksConsumables.lua` detects active consumables and updates inventory highlights.
- `UITweaksImmersion.lua` applies the optional Immersion and ConsolePort controller compatibility layer.
- `UITweaksDebug.lua` contains alpha-only diagnostics and debugging UI.
- `Libs/` contains embedded Ace3 dependencies.
- `Textures/` and the root icon files contain addon artwork.

## Component Interactions

AceAddon initializes the shared database, then passes the addon instance to the options, consumables, Immersion compatibility, and debug modules. Settings are stored in the AceDB profile. Lifecycle and game events enter through `UITweaks.lua`, which delegates specialized work to the relevant module.

The Immersion compatibility module activates only when its setting is enabled and both Immersion and ConsolePort are loaded. It wraps Immersion's controller command and hint methods in memory, leaving Immersion's installed files unchanged. A UI reload removes the wrappers; UITweaks reapplies them only if the setting remains enabled.

The minimap shortcut registers through LibDataBroker and LibDBIcon when another enabled addon provides those libraries, allowing minimap managers to discover it through standard callbacks. A standalone button provides the same shortcut when those libraries are unavailable.
