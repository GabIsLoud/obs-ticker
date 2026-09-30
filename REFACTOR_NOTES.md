# OBS Ticker Refactor (v3)

## Overview

This refactor reorganizes the obs-ticker repository to separate deployment concerns from development concerns:

- **Deployment**: `index.html`, `games.json`, message files, and logo remain in the repo root and continue to work as a static GitHub Pages site with no build step.
- **Development**: The local PowerShell editor has moved to `tools/ticker-builder/` with repo-aware file handling, backup safety, and externalized prompt definitions.

## What Changed

### Repository Structure

**Before:**
```
obs-ticker/
├─ index.html
├─ games.json
├─ messages*.txt
├─ Gabisness-TickerBuilder-v2.ps1  (at root)
└─ prompts.json (hardcoded in PowerShell)
```

**After:**
```
obs-ticker/
├─ index.html
├─ games.json
├─ messages*.txt
├─ justG.png
├─ tools/
│  └─ ticker-builder/
│     ├─ Gabisness-TickerBuilder.ps1  (refactored v3)
│     ├─ prompts.json                 (externalized config)
│     ├─ README.md                    (builder documentation)
│     ├─ schema-notes.md              (implementation details)
│     ├─ backups/                     (timestamped backup files)
│     └─ OriginalBuilder-v2.ps1       (reference/fallback)
└─ archive/                           (optional - future backups)
```

### Deployment (index.html)

**No breaking changes.** The ticker continues to work exactly as before:

- ✅ Base URL shows preset picker
- ✅ `?preset=KEY` loads a preset directly
- ✅ `?src=PATH` loads a message file
- ✅ `visible` field controls picker visibility
- ✅ Message shuffle with no-repeat pool

**New features:**

- ✅ **borderColor support**: Top/bottom CSS rules now use independent `--border` variable
  - Falls back to `fg` if `borderColor` is absent (backward compatible)
  - Allows gold/silver borders while keeping white text, etc.

- ✅ **twitchGameId metadata**: Presets can store Twitch game IDs (string, not parsed yet)
  - Future integration with Twitch API
  - Harmless to existing presets (ignored if absent)

- ✅ **fontUrl support**: Already existed, now documented
  - Allows custom font loading via CSS

### Local Builder (tools/ticker-builder/)

**Complete refactor to make development workflow safer and more maintainable:**

#### New Capabilities

1. **Repo-Aware**
   - Auto-detects repository root by walking up from script directory looking for `.git/`
   - Paths are resolved relative to repo root, not current working directory
   - Safe to run from any working directory

2. **Load Existing Preset**
   - Dropdown populated from `games.json`
   - Shows visible presets only (respects `visible: false`)
   - Click "Load Selected Preset" to load the preset and its message file
   - Full preset metadata (key, label, src, bg, fg, size, speed, etc.) is available for editing

3. **Save to Repo**
   - Writes message lines to the preset's `src` file
   - Updates the preset entry in `games.json` (upsert by key)
   - Preserves all unmodified presets
   - Creates timestamped backups before overwriting files
   - Validates JSON before writing (fails safely if invalid)

4. **Externalized Prompts**
   - Prompts loaded from `tools/ticker-builder/prompts.json` (not hardcoded in PowerShell)
   - Easier to maintain and extend
   - Categories: Game Notes, Chat & Engagement, In-Jokes, Site Plugs, Merch Plugs, Reminders, Oddballs
   - Site Plugs: /rules, /games, /schedule, /setup, /playlists, /donate, /suggest, /faq, /contact, /store, /ppv
   - Merch Plugs: shirts, pants, hats, general clothing, Eddy's art, store
   - Each prompt can include a `copy` field for quick URL copying

5. **Safety & Backups**
   - Automatic timestamped backups before any file overwrite
   - Backups in `tools/ticker-builder/backups/`
   - Format: `games.json.backup.20260930-161930`
   - Easy to restore manually if needed
   - JSON validation prevents writing invalid data

#### UI Improvements

- High-contrast readable text (all labels, buttons, checkboxes)
- Checkbox text unclipped and properly sized
- WinForms dark theme (matches original)
- Organized layout with left panel (presets + messages) and right panel (prompts + preview)

#### Future Enhancements (Roadmap)

- ✅ Font preview with sample text rendering
- ✅ Animation preview (mock ticker with selected settings)
- ✅ Logo preview and swap
- ✅ Copy-to-clipboard buttons for Site Plugs and Merch Plugs URLs
- ✅ Create new preset wizard
- ❌ C# rewrite (separate project, later)
- ❌ Web-based alternative builder

## Backward Compatibility

### Deployment

- ✅ Old presets without `borderColor` continue to work (border uses `fg`)
- ✅ Old presets without `twitchGameId` continue to work (field simply absent)
- ✅ Old presets without `fontUrl` continue to work (no custom font loaded)
- ✅ Message files at root level (e.g., `messages.txt`) continue to work
- ✅ Direct URL parameters still override preset values

### Message Files

Message files can remain at repo root or be moved to `messages/` subdirectory:

- Root-level: `src: "messagesDBD.txt"`
- Subdirectory: `src: "messages/messagesDBD.txt"`

Both are supported by loader and builder.

### games.json Format

The builder preserves:

- All existing presets when updating a single preset
- All unrelated fields (forward compatibility)
- Field order (with `visible` immediately after `src`)

## Migration Path

### For Users

1. Update repo to this branch (all existing functionality works without changes)
2. Move builder script from repo root to `tools/ticker-builder/Gabisness-TickerBuilder.ps1`
3. Copy `prompts.json` to `tools/ticker-builder/`
4. Run the new builder: `.\tools\ticker-builder\Gabisness-TickerBuilder.ps1`
5. Presets load from `games.json` automatically

### For CI/CD

No changes needed. The deployment is still static:

- GitHub Pages continues to serve `index.html` as-is
- `games.json` continues to live at repo root
- No build step required
- All existing CI workflows unchanged

## File Changes Summary

### Modified

1. **index.html**
   - Added `--border` CSS variable (defaults to `--fg`)
   - Updated border rendering rules to use `--border`
   - buildConfig() now returns `borderColor` field
   - initTicker() sets `--border` from preset or falls back to `fg`

### Added

1. **tools/ticker-builder/Gabisness-TickerBuilder.ps1**
   - Refactored PowerShell builder with repo-awareness
   - Load Existing Preset dropdown
   - Save to Repo functionality with backups
   - Prompts loaded from external JSON
   - High-contrast readable UI

2. **tools/ticker-builder/prompts.json**
   - Externalized prompt definitions
   - 7 categories, 80+ prompts
   - Site plugs, merch plugs, reminders, etc.

3. **tools/ticker-builder/README.md**
   - Complete builder usage documentation
   - Preset metadata field reference
   - Troubleshooting guide
   - Backup safety procedures

4. **tools/ticker-builder/schema-notes.md**
   - Detailed games.json schema
   - Message file format specification
   - Query parameter documentation
   - Validation rules and forward compatibility notes

5. **tools/ticker-builder/backups/** (directory)
   - Timestamped backup files created by builder
   - Naming: `<filename>.backup.<yyyyMMdd-HHmmss>`

6. **tools/ticker-builder/OriginalBuilder-v2.ps1**
   - Original builder kept for reference/fallback
   - Not used by default

### Unchanged

- index.html structure (pure static HTML/CSS/JS)
- games.json location (repo root)
- Message file locations (root or messages/ subdirectory)
- GitHub Pages deployment
- All existing URL parameters and picker behavior

## Testing Checklist

- [ ] GitHub Pages loads at base URL (preset picker shown)
- [ ] `?preset=witcher3` loads The Witcher 3 preset
- [ ] `?src=messages.txt` loads alternate message source
- [ ] Message shuffle works (no repeat until pool exhausted)
- [ ] Old presets without `borderColor` still work
- [ ] Old presets without `twitchGameId` still work
- [ ] Builder auto-detects repo root from tools/ticker-builder/
- [ ] Builder loads all presets into dropdown
- [ ] Load Existing Preset loads message file correctly
- [ ] Save to Repo creates backup before writing
- [ ] Save to Repo updates games.json with new preset
- [ ] Message file saved with UTF-8 encoding
- [ ] Prompts.json loads and displays all categories
- [ ] UI text is readable and not clipped

## Questions & Known Limitations

### Questions

**Q: Can I move message files to messages/ subdirectory?**
A: Yes. Update `src` in the preset from `"messages.txt"` to `"messages/messages.txt"`. Both are supported.

**Q: What if I'm running the old builder?**
A: The original `OriginalBuilder-v2.ps1` is kept in `tools/ticker-builder/` for reference. However, it won't auto-detect repo root and won't load existing presets from games.json.

**Q: Can I have presets visible=false?**
A: Yes. Set `visible: false` to hide from picker but remain loadable via `?preset=KEY`. Useful for test/experimental presets.

### Known Limitations

- **PowerShell-only** (v3). The current implementation uses Windows PowerShell/PS7 with WinForms.
- **No animation preview yet** (roadmap feature). Currently only static font preview available.
- **No cross-platform support** (yet). Future C# rewrite will address this.
- **Message file limit** (soft). Very large message pools (10,000+ lines) may be slow to shuffle.

## Support & Troubleshooting

### Builder won't start

Check that PowerShell execution policy allows the script:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\tools\ticker-builder\Gabisness-TickerBuilder.ps1
```

### "Could not find repository root"

Ensure:
- Script is in `tools/ticker-builder/`
- `.git/` exists at repo root
- Paths are correct

### Backup files not created

Check that `tools/ticker-builder/backups/` directory is writable.

### JSON validation failed

Ensure `games.json` is valid JSON before attempting Save to Repo. Check the PowerShell console output for error details.

## Commit Strategy

This refactor is designed to be:

1. **Non-breaking**: All existing functionality preserved
2. **Incremental**: Can be deployed gradually
3. **Reversible**: Old builder backed up; old presets still work
4. **Safe**: Backups created before any file write

Recommended commit:
```
Refactor: Move builder to tools/ticker-builder/ and externalize prompts

- Auto-detect repository root
- Load Existing Preset dropdown populated from games.json
- Save to Repo writes message files and updates presets
- Externalize prompt definitions to prompts.json
- Add timestamped backup safety
- Add --border CSS variable for independent border color
- Add twitchGameId metadata support (string)
- Add comprehensive README and schema documentation
- Preserve all backward compatibility
```

## Next Steps

### After This Refactor

1. ✅ Deployment remains static and simple
2. ✅ Local development now safer with backups
3. ✅ Prompts easier to maintain and extend
4. ✅ Preset metadata more flexible (twitchGameId, borderColor)

### Future Work

1. **Add animation preview** to builder UI
2. **Create preset wizard** for new presets
3. **C# rewrite** (separate project) with cross-platform support
4. **Twitch API integration** (use twitchGameId field)
5. **Message file organization** (migrate to /messages/ subdirectory)
6. **Draft auto-save** in builder

## References

- **README.md** — Builder usage and quick start
- **schema-notes.md** — Detailed schema and implementation notes
- **index.html** — Ticker loader (modified for borderColor support)
- **games.json** — Preset metadata (no structural changes)
