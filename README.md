# VoidMark Debug v1.0.0

Standalone error collection addon for WoW Classic/Forever-style clients.

## Install
Copy the **VoidMarkDebug** folder (containing `VoidMarkDebug.toc`) into your client's `Interface/AddOns`, or create a Windows junction to that inner folder. Use `/console scriptErrors 1` to also show the stock popup (optional).

Commands: `/vmd` opens or hides the viewer; `/vmd report` selects a copyable report; `/vmd count` displays counts; `/vmd test` adds a synthetic test entry; `/vmd clear` removes captured entries.

Errors are grouped by normalized message and captured with the stack text delivered to WoW's Lua error handler. SavedVariables persist up to 250 distinct groups across reloads. The full report can be selected and copied with Ctrl+C. Filtering and optional character-name redaction are provided. Redaction is best-effort, so review reports before sharing.

**Account separation:** WoW account SavedVariables are stored separately in each account's WTF folder. This addon cannot read or automatically merge data across WoW accounts/computers. Copy the report from each account to ChatGPT separately.

**Compatibility:** Coexists with the current registered error handler by forwarding captured errors to it. Another addon may replace the handler after login; if errors are missing, test without competing error-capture addons. Lua-level errors only: client crashes or freezes cannot be captured.

**Testing:** Use `/vmd test`, `/vmd report`, then `/reload` and confirm entries remain. Test in-game on your client; this repository has not been validated inside the WoW client.
