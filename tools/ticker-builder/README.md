# Gabisness OBS Ticker Builder v3

A local PowerShell/WinForms editor for managing OBS overlay ticker presets and messages, with repo-aware file handling and automatic backup creation.

## Quick Start

1. Ensure you're on Windows with PowerShell 5.1 or higher.
2. Navigate to this directory and run:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   .\Gabisness-TickerBuilder.ps1
   ```

3. The builder will auto-detect your repository root by looking for `.git`.
4. Load an existing preset from the dropdown or create a new one.
5. Edit ticker messages and configure preset metadata.
6. Click **Save to Repo** to write changes back to `games.json` and message files.

## Repository Structure

The builder expects:

```
obs-ticker/
├─ .git/                          (repo root, auto-detected)
├─ games.json                     (preset metadata - loaded and updated by builder)
├─ index.html                     (deployed ticker - not modified by builder)
├─ justG.png                      (logo - referenced in presets)
├─ messages/                      (optional - message files directory)
│  ├─ messagesDBD.txt
│  ├─ messagesWitcher3.txt
│  └─ ...
└─ tools/ticker-builder/
   ├─ Gabisness-TickerBuilder.ps1 (this script)
   ├─ prompts.json                (prompt templates - loaded by builder)
   ├─ README.md                   (this file)
   ├─ backups/                    (timestamped backups of games.json and message files)
   └─ schema-notes.md             (implementation notes)
```

## Preset Metadata

Each preset in `games.json` supports the following fields:

```json
{
  "key": "witcher3",
  "label": "The Witcher 3",
  "src": "messages/messagesWitcher3.txt",
  "visible": true,
  "twitchGameId": "390541",
  "bg": "linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)",
  "fg": "#FFFFFF",
  "borderColor": "#D4AF37",
  "size": 32,
  "speed": 158,
  "logo": "justG.png",
  "collapse": 510000,
  "fadeMs": 470,
  "gap": 14,
  "rules": "1",
  "font": "\"Segoe UI\", Arial, sans-serif",
  "fontUrl": ""
}
```

### Field Descriptions

- **key**: Unique identifier (lowercase alphanumeric, no spaces)
- **label**: Display name for the preset picker
- **src**: Path to the message file (relative to repo root; supports `messages/` or root-level)
- **visible**: Boolean - if `true`, appears in the base preset picker; if `false`, loadable only via `?preset=key` URL
- **twitchGameId**: Twitch category ID (string) - used as reference metadata, not yet integrated into the overlay
- **bg**: CSS background (solid color or gradient)
- **fg**: Foreground text color (hex)
- **borderColor**: Top/bottom border color (hex, optional; falls back to `fg` if not present)
- **size**: Font size in pixels
- **speed**: Scroll speed (pixels per second)
- **logo**: Logo filename (relative to repo root)
- **collapse**: Collapse delay in milliseconds (how long a message stays visible before scrolling)
- **fadeMs**: Fade transition duration in milliseconds
- **gap**: Gap between messages in pixels
- **rules**: Rendering rules version (string)
- **font**: CSS font family string
- **fontUrl**: Optional @font-face URL (empty string or omitted if not used)

## Load Existing Preset Workflow

1. Open the builder.
2. The **Load Existing Preset** dropdown is populated from `games.json` (visible presets only).
3. Select a preset and click **Load Selected Preset**.
4. The builder loads the preset's metadata and message file (`src`).
5. Edit messages or metadata as needed.
6. Click **Save to Repo** to persist changes.

## Save to Repo

The **Save to Repo** action:

1. **Creates timestamped backups** (in `tools/ticker-builder/backups/`):
   - Before overwriting `games.json`
   - Before overwriting an existing message file
   - Format: `games.json.backup.20260930-161930`

2. **Writes the message file**:
   - Saves edited messages to the preset's `src` path
   - Creates the `messages/` directory if needed
   - Preserves UTF-8 encoding

3. **Updates `games.json`**:
   - Upserts the preset (updates if it exists by key, inserts if new)
   - Preserves all unmodified presets
   - Maintains `visible` field position immediately after `src`
   - Ensures valid JSON before writing
   - Does NOT overwrite if JSON validation fails

## Prompts Configuration

Prompt definitions live in `prompts.json` (not hardcoded in PowerShell). The builder loads prompts at startup and displays them in UI tabs organized by category:

- **Game Notes** — gameplay-specific observations and tips
- **Chat & Engagement** — how chat can help or participate
- **Stream In-Jokes** — recurring community bits and humor
- **Site Plugs** — URLs for rules, schedule, setup, playlists, donate, suggest, FAQ, contact, store, and OnlyFans PPV
- **Merch Plugs** — promotional lines for shirts, pants, hats, general clothing, Eddy's handmade art, and store
- **Reminders & CTAs** — hydration, posture, subscribe, membership, tilt management, breaks
- **Oddballs** — extra slots for one-off lines

Each prompt may include a `copy` field containing a URL or reference that can be quickly copied to clipboard via the builder's UI.

## Backup Safety

Backups are created **before** any file overwrite:

- File location: `tools/ticker-builder/backups/`
- Naming: `<filename>.backup.<timestamp>`
  - Example: `games.json.backup.20260930-161930`
- Timestamps use format: `yyyyMMdd-HHmmss`

To restore from backup:
1. Locate the backup file in `backups/`
2. Manually copy it back to the original location (repo root or message file path)
3. Rename to the original filename

## Production Deployment Compatibility

The production ticker (`index.html`) remains:

- **A static GitHub Pages deployment** — no build step, no Node.js, no framework
- **Directly served from repo root** — GitHub Pages hosts `index.html` as-is
- **Backward compatible** — existing presets without `borderColor`, `twitchGameId`, or `fontUrl` continue to work

### CSS Variables (index.html)

If `borderColor` is present in a preset, `index.html` uses the `--border` CSS variable for top/bottom rules.
If `borderColor` is absent, the ticker falls back to the `--fg` (foreground) color for border rendering.

Example in index.html:
```javascript
const borderColor = preset.borderColor || preset.fg;
root.style.setProperty('--border', borderColor);
```

### Message File Location Flexibility

- Old presets with `src: "messagesDBD.txt"` (root-level) continue to work
- New presets can use `src: "messages/messagesDBD.txt"` (subdirectory)
- The builder auto-detects both locations when loading

## Limitations & Known Issues

- **PowerShell-only** — Windows-only (this version). A future C# rewrite may provide cross-platform support.
- **WinForms UI** — requires Windows. Terminal-only environments are not supported.
- **Message file encoding** — always saved as UTF-8 without BOM. If you manually edit message files, ensure they are UTF-8 compatible.
- **Large message pools** — if a message file has thousands of lines, preview/shuffle operations may be slow.

## Future Enhancements

Potential improvements (not yet implemented):

- Font preview with live rendering of sample text
- Animation preview (see messages scroll in real-time)
- Logo preview (load and display selected logo file)
- Copy-to-clipboard buttons for Site Plugs and Merch Plugs URLs
- Create new preset wizard
- Draft auto-save
- Dark mode toggle in UI
- Web-based builder as alternative to PowerShell

## Troubleshooting

### "Could not find repository root (.git folder)"
- Ensure you're running the script from within the `tools/ticker-builder/` directory.
- Ensure `.git/` exists at the repo root.

### "games.json not found"
- Ensure `games.json` exists at the repo root.
- The builder can auto-create a basic `games.json` if it's missing (future version).

### "prompts.json not found"
- Ensure `prompts.json` exists in `tools/ticker-builder/`.
- Copy from the extracted handoff files if needed.

### Message file not loading
- Check that the `src` path in the preset is correct (relative to repo root).
- Ensure the message file exists at that path.
- Check file encoding is UTF-8.

### Changes not saved to repo
- Check that `Save to Repo` completed without errors (check PowerShell console output).
- Verify `games.json` was updated (check file timestamp).
- Look in `backups/` to confirm the backup was created.

## Support

For questions or issues, refer to the main repository's documentation or create an issue on GitHub.
