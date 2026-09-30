# Preset Schema & Implementation Notes

## Overview

This document describes the structure of `games.json`, the message file format, and how the ticker loader (`index.html`) interprets and applies preset metadata.

## games.json Structure

`games.json` is a JSON file at the repo root containing an array of preset objects.

### File Format

```json
{
  "games": [
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
    },
    ...
  ]
}
```

### Field Reference

#### Required Fields

- **key** (string)
  - Unique identifier for the preset
  - Lowercase alphanumeric characters and hyphens only (normalized by loader)
  - Used in URL parameters: `?preset=witcher3`
  - Example: `"witcher3"`

- **label** (string)
  - Display name in the preset picker
  - Human-readable, can include spaces
  - Example: `"The Witcher 3"`

- **src** (string)
  - Path to the message file, relative to repo root
  - Can be root-level (`"messagesDBD.txt"`) or in subdirectory (`"messages/messagesWitcher3.txt"`)
  - Loader auto-detects both locations
  - Example: `"messages/messagesWitcher3.txt"`

#### Visibility & Metadata

- **visible** (boolean, default: true)
  - If `true`, appears in the base preset picker
  - If `false`, not shown in picker but remains loadable via `?preset=key` URL
  - Example: `true`

- **twitchGameId** (string)
  - Twitch category ID for reference metadata (not yet integrated into overlay)
  - Stored as string to avoid numeric truncation
  - Future: may be used for stream metadata integration
  - Example: `"390541"`

#### Styling

- **bg** (string, default: `"rgba(0,0,0,0.6)"`)
  - CSS background value for the ticker container
  - Supports solid colors, gradients, images
  - Examples:
    - Solid: `"#1a1a2e"`
    - Gradient: `"linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)"`
    - RGBA: `"rgba(0,0,0,0.6)"`
    - Image: `"url('bg.png')"`

- **fg** (string, default: `"#ffffff"`)
  - CSS color value for text foreground
  - Hex colors recommended for consistency
  - Example: `"#FFFFFF"`

- **borderColor** (string, optional, default: uses `fg`)
  - CSS color value for top/bottom border rules
  - Only used if `"rules": "1"` is set
  - If absent, loader falls back to `fg` value
  - Allows independent border styling from text color
  - Hex colors recommended
  - Example: `"#D4AF37"`

- **font** (string, default: system UI stack)
  - CSS font-family string
  - Should include fallbacks for cross-platform support
  - System fonts: quoted family names with fallbacks
  - Examples:
    - `"\"Segoe UI\", Arial, sans-serif"`
    - `"Georgia, serif"`
    - `"'Courier New', monospace"`

- **fontUrl** (string, default: empty)
  - Optional URL to a custom font file (e.g., from Google Fonts)
  - If present, loader injects a `<link>` tag for the font
  - Should match the `font` family name
  - Example: `"https://fonts.googleapis.com/css2?family=Roboto:wght@700"`
  - Leave empty string `""` or omit if using system fonts only

#### Animation & Layout

- **size** (number, default: 48)
  - Font size in pixels
  - Valid range: 12–200
  - Affects line height and layout
  - Example: `32`

- **speed** (number, default: 160)
  - Scroll speed in pixels per second
  - Valid range: 20–2000
  - Lower = slower scroll, higher = faster
  - Example: `158`

- **logo** (string, default: `"justG.png"`)
  - Filename of the logo image (relative to repo root)
  - Displayed at line height before and after messages
  - Aspect ratio preserved, height = 1em
  - Example: `"justG.png"`

- **collapse** (number, default: 0)
  - Pause duration in milliseconds before scrolling the next message
  - How long a message "rests" at full visibility
  - Example: `510000` (510 seconds)

- **fadeMs** (number, default: 320)
  - Fade transition duration in milliseconds
  - Applied when hiding/showing the ticker
  - Example: `470`

- **gap** (number, default: 14)
  - Horizontal gap between logo and message text, in pixels
  - Also used for spacing between repeated logo instances
  - Example: `14`

#### Rendering & Rules

- **rules** (string, default: `"0"`)
  - Flag to enable decorative top/bottom borders
  - Expected values: `"1"` (enabled) or `"0"` (disabled)
  - When `"1"`, CSS rules are rendered using `--border` color
  - Example: `"1"`

- **paddingY** (implied, see query param below)
  - Vertical padding (top/bottom) of ticker container
  - Set via `?py=` query parameter (not stored in preset)
  - Default: 6 pixels

- **paddingX** (implied, see query param below)
  - Horizontal padding (left/right) of ticker container
  - Set via `?px=` query parameter (not stored in preset)
  - Default: 16 pixels

## Message File Format

Message files are UTF-8 text files with one message per line.

### Requirements

- **Encoding**: UTF-8 (no BOM)
- **Line endings**: LF (`\n`) or CRLF (`\r\n`)
- **Blank lines**: Ignored by loader
- **Whitespace**: Leading/trailing spaces trimmed
- **Duplicates**: Removed (exact case-insensitive match)

### Example: `messages/messagesWitcher3.txt`

```
Geralt of Rivia agrees: always loot the bodies.
Time for bed.
Wind's howling.
What now, you piece of filth?
Do you see the Sorrow?
Better save my game before the next fight.
Roach, you're the best horse ever.
Yennefer would have a witty comment here.
The White Wolf doesn't back down from a contract.
Another round of Gwent?
```

## Query Parameters (index.html)

The ticker loader supports URL query parameters for overriding preset fields:

```
https://example.com/obs-ticker/?preset=witcher3&?size=40&speed=200&fg=%23FF0000
```

### Supported Parameters

- `?preset=KEY` — Load preset by key (e.g., `?preset=witcher3`)
- `?src=PATH` — Override message file path
- `?bg=COLOR` — Override background (URL-encoded)
- `?fg=COLOR` — Override foreground color (URL-encoded)
- `?font=NAME` — Override font family
- `?fontUrl=URL` — Override custom font URL
- `?logo=FILE` — Override logo filename
- `?size=NUM` — Override font size (12–200)
- `?speed=NUM` — Override scroll speed (20–2000)
- `?py=NUM` — Vertical padding (0–100)
- `?px=NUM` — Horizontal padding (0–200)
- `?gap=NUM` — Message gap (0–200)
- `?collapse=NUM` — Collapse delay (0–3600000 ms)
- `?fadeMs=NUM` — Fade duration (0–60000 ms)
- `?rules=1` — Enable top/bottom border rules
- `?direction=rtl` — Right-to-left text direction
- `?manifest=URL` — Override games.json URL (default: `games.json`)

Parameters override preset values when specified.

### URL Encoding

Color values must be URL-encoded:
- `#` → `%23`
- Space → `%20`
- Quotes → `%22`

Example:
```
?fg=%23D4AF37
```

## Backward Compatibility

### Missing Optional Fields

The loader gracefully handles presets missing optional fields:

- If `borderColor` is absent → uses `fg` for border rendering
- If `twitchGameId` is absent → field is simply not present (no error)
- If `fontUrl` is absent or empty → no custom font injected
- If `rules` is absent → treated as `"0"` (no border rules)

### Legacy Message Paths

The loader supports both:

1. **Root-level messages**:
   ```json
   { "src": "messagesDBD.txt" }
   ```

2. **Subdirectory messages**:
   ```json
   { "src": "messages/messagesDBD.txt" }
   ```

The builder may migrate presets to the `messages/` subdirectory, but old presets at root level continue to work.

## CSS Variables (index.html)

The ticker uses CSS custom properties for styling. These are set dynamically based on the loaded preset:

```css
--bg: rgba(0,0,0,0.6);
--fg: #ffffff;
--border: var(--fg);  /* Falls back to fg if not explicitly set */
--font: system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
--size: 48;
--speed: 160;
--paddingY: 6;
--paddingX: 16;
--gapX: 12;
--collapseMs: 0;
--fadeMs: 320;
--logoUrl: "logo.png";
--messagesUrl: "messages.txt";
--shadow: 0 1px 2px rgba(0,0,0,0.35);
```

When a preset is loaded, these variables are updated to match the preset's values.

## Data Validation

### JSON Schema (implicit)

```typescript
interface Preset {
  key: string;
  label: string;
  src: string;
  visible?: boolean;
  twitchGameId?: string;
  bg?: string;
  fg?: string;
  borderColor?: string;
  font?: string;
  fontUrl?: string;
  size?: number;
  speed?: number;
  logo?: string;
  collapse?: number;
  fadeMs?: number;
  gap?: number;
  rules?: string;
  [key: string]: any;  // Unknown fields are tolerated
}

interface GamesJson {
  games?: Preset[];
  [key: string]: any;  // Other root properties are tolerated
}
```

### Validation Rules (Loader)

1. **Unknown fields** are silently ignored (forward compatibility)
2. **Missing required fields** cause preset to be skipped (logged to console)
3. **Invalid field values** are coerced or replaced with defaults
4. **Malformed JSON** fails silently; empty preset list is used

The goal is robustness: if anything goes wrong, the ticker still loads with fallback defaults.

## Builder (tools/ticker-builder/Gabisness-TickerBuilder.ps1)

The PowerShell builder ensures:

1. **JSON validity** before writing `games.json`
2. **Backup creation** before overwriting files
3. **UTF-8 encoding** for all text files
4. **Relative paths** (paths are relative to repo root, not script location)
5. **Preset upsert** (updates existing presets by key, inserts new ones)
6. **Field order** (places `visible` immediately after `src` in JSON output)

### Builder Safety Measures

- Creates timestamped backups in `tools/ticker-builder/backups/`
- Never overwrites a file if the write fails
- Validates JSON before committing to disk
- Preserves unrelated presets when updating `games.json`
- Respects relative paths and auto-detects repo root

## Future Enhancements

### twitchGameId Integration

Currently stored as metadata but not used. Potential uses:

- Auto-fetch game metadata from Twitch API
- Link presets to Twitch Categories
- Provide stream context metadata for overlays

### fontUrl & Web Fonts

Already supported. Presets can reference:

- Google Fonts: `https://fonts.googleapis.com/css2?family=Roboto:wght@700`
- Custom CDN fonts
- Local font files

### Message File Formats

Currently supports:
- Plain text (one line per message)
- JSON arrays (future support)

Could be extended to:
- CSV with message + metadata
- Database query results
- Live API endpoints
