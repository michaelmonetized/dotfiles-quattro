# Browser Keys

Edit `~/.config/browser-keys.jsonc`, then run `~/.config/desktop/bin/browser-keys-install` to apply. JSONC comments and trailing commas are supported. Each chord maps to one `action` (extension API) or `shortcut` (a native browser chord). Existing desktop bindings are retained outside browser windows.

## Load the extensions

Native messaging hosts are registered by the installer. No website content scripts, network listeners, or remote servers are used.

- Chromium/Chrome: open `chrome://extensions`, enable Developer mode, choose **Load unpacked**, and select `~/.config/browser-keys/chrome`.
- Zen: open `about:debugging#/runtime/this-firefox`, choose **Load Temporary Add-on**, and select `~/.config/browser-keys/zen/manifest.json`. Temporary add-ons disappear after restart. A persistent standard installation requires Mozilla signing; no signing credentials are configured by this project.

The browser automation tool cannot open browser extension-management pages, so those load steps are manual. Until loaded, extension actions display a notification instead of silently doing nothing. Native shortcut mappings work immediately.

Super+Alt+Up/Down selects adjacent visible tabs by browser tab index, wrapping at the ends and skipping hidden tabs. This matches the browser's native tab order; third-party sidebar extensions with an independent custom sort are not exposed by the tabs API. Zen-specific Glance and split-view commands remain with Zen's existing settings; Chrome has no equivalent extension API for those actions.

The initial portable mappings were derived from the local Zen shortcut file. Super+1…9 selects tabs; Super+T/W opens/closes tabs; Super+Shift+T restores; Super+Shift+D toggles pinning; Ctrl+D duplicates; Super+M toggles mute; Super+Shift+C copies the URL. See JSONC for the rest.

Sources: https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging and https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/tabs/query

Run `node desktop/tests/browser-keys.test.cjs` from `~/.config` to verify visible-order selection and focus guards.

## Packed transport

`chrome.crx` is the distributable package; `chrome.pem` is its private signing key and stays on the build machine. Both generated files are excluded from Git. Repack with the same PEM to retain the package ID. The native-host installer registers both `chrome-id` (unpacked) and `chrome-packed-id` (packed).

On another machine, copy the CRX, install the versioned Browser Keys configuration and helper scripts, then run `~/.config/desktop/bin/browser-keys-install` before loading the extension. The CRX alone does not include the native bridge or compositor bindings.
