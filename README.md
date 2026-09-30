# OBS ticker

A static browser overlay that scrolls shuffled messages between two logos, with game-specific themes and an optional pause between messages. No build step or runtime packages are required.

## OBS setup

Serve this folder over HTTP. For example, with Python installed, run `python -m http.server 8000 --bind 127.0.0.1` from the repository directory and keep that terminal running.

Add an OBS Browser Source using `http://127.0.0.1:8000/index.html?preset=witcher3`. Set the source width to match your scene and choose a height that fits the font and vertical padding (100 pixels is a useful starting point). Relative message and logo paths are resolved against the page URL. Fetch-based loading requires HTTP hosting; use the URL field rather than OBS's Local File option.

Without a preset or direct source, the page shows the visible preset buttons. Use OBS's Interact window to select one. Presets with `visible: false` are hidden from the picker but remain available by URL. Refreshing restores the URL's selection; clicking a button does not change the URL.

All current presets use `collapse: 510000`: after each message, the overlay hides for 8 minutes 30 seconds. Add `&collapse=0` for continuous scrolling.

## URL settings

Query values override preset settings. URL-encode values containing spaces, `#`, `&`, or other special characters.

| Parameter | Meaning |
| --- | --- |
| `preset` | Key from `games.json`, e.g. `witcher3` or `generic` |
| `manifest` | Alternate manifest URL; defaults to `games.json` |
| `src` | Message URL; newline-delimited text or a JSON array when the URL ends in `.json` |
| `logo` | Logo URL; defaults to bundled `justG.png` |
| `size` | Font size in pixels, 12–200 |
| `speed` | Scroll speed in pixels per second, 20–2000 |
| `py`, `px` | Vertical and horizontal padding in pixels |
| `gap` | Gap between logo and text in pixels |
| `collapse` | Hidden time between messages in milliseconds; zero disables it |
| `fadeMs` | Fade duration in milliseconds |
| `bg`, `fg` | CSS background and text color |
| `font`, `fontUrl` | CSS font family and optional font stylesheet URL |
| `rules` | `1` displays decorative horizontal rules; `0` disables them |
| `reloadEvery` | Reload message source every N slide requests; zero disables it |
| `direction` | Existing logo-order option (`ltr` or `rtl`); scrolling moves right to left in both modes |

Example: `http://127.0.0.1:8000/index.html?preset=generic&collapse=0&size=30&speed=160`

The manifest is loaded at startup. Message files are loaded when selecting a preset, with optional periodic reloads. External sources must permit browser access through CORS. The game themes use Google Fonts with local fallback fonts.

## Files and editing

- `index.html`: page, styles, animation, message loading, and JavaScript controls.
- `games.json`: preset keys, labels, visibility, message paths, and theme settings.
- `*.txt`: message collections, one message per line. Blank lines and case-insensitive duplicates are removed during loading.
- `justG.png`: shared logo.
- `tests/ticker.test.cjs`: regression checks using Node's built-in test runner and a simulated browser environment.

To add a preset, create a message file and add an entry to `games.json` with a unique key, label, and source. Copy an existing entry to retain its styling fields. Unlisted text files can still be selected with `src`.

Browser console controls are available through `window.OBSTicker`: `presets`, `choosePreset(key)`, `setMessages(array)`, `next()`, and `showPicker()`. `next()` starts a slide only when the ticker is idle; it does not interrupt an animation or timed pause.

## Validation

With Node.js installed, run `node --test tests/ticker.test.cjs`. Checks cover missing numeric defaults, explicit overrides, the default logo, preset-switching races, animation cancellation, and manifest asset references. Actual OBS rendering should also be checked before a live stream.
