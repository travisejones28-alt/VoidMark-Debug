# VoidMark Debug v1.2.0 — WoW Forever

Standalone Lua error collection addon for **WoW Forever (Interface 16001)**. The original Classic Era functionality is retained.

## Install
The repository root now directly contains `VoidMarkDebug.toc` and `VoidMarkDebug.lua`. Install it as an AddOns folder named **VoidMarkDebug**, or create a Windows junction named `VoidMarkDebug` pointing to this repository root. Do not install an additional nested folder. Use `/console scriptErrors 1` to also show the stock popup (optional).

Commands: `/vmd` opens or hides the viewer; `/vmd report` selects a copyable report; `/vmd count` displays counts; `/vmd top` shows the five most frequent errors; `/vmd notify` toggles the on-screen indicator; `/vmd blizzard` toggles Blizzard error popups; `/vmd test` adds a synthetic test entry; `/vmd clear` removes captured entries.

Errors use a cached signature lookup to minimize overhead during error floods and are grouped by normalized message and captured with the stack text delivered to WoW's Lua error handler. SavedVariables persist up to 250 distinct groups across reloads. The full report can be selected and copied with Ctrl+C. Filtering and optional character-name redaction are provided. Redaction is best-effort, so review reports before sharing.

**Account separation:** WoW account SavedVariables are stored separately in each account's WTF folder. This addon cannot read or automatically merge data across WoW accounts/computers. Copy the report from each account to ChatGPT separately.

**Compatibility:** Coexists with the current registered error handler by forwarding captured errors to it. Another addon may replace the handler after login; if errors are missing, test without competing error-capture addons. Lua-level errors only: client crashes or freezes cannot be captured.

**Forever changes:** Detects missing BackdropTemplate support before constructing the UI, caches error signatures so repeated failures avoid scanning up to 250 entries, keeps the cache synchronized when clearing or evicting logs, and adds `/vmd top` for tracking error floods. The client interface remains 16001.\n\n**Testing:** Use `/vmd test`, `/vmd report`, then `/reload` and confirm entries remain. Test in-game on your client; this repository has not been validated inside the WoW client.


## Silent error mode (default in v1.2)
VMD records errors without forwarding them to the prior Blizzard handler. A small clickable error-count indicator appears after the first captured error each session, and can be dragged. Click to view the report. /vmd notify toggles the counter, /vmd blizzard restores or suppresses forwarding. Preferences persist per account. Competing addons may replace the error handler after VMD loads. This does not fix underlying Lua errors.

## Updates
Install and update through VoidMark Warpath.
