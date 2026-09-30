#requires -version 5.1
<#
Gabisness OBS Ticker Builder v2
Windows PowerShell / PowerShell 7 on Windows
WinForms prompt editor + preset designer + preview/animation.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Drawing2D
Add-Type -AssemblyName System.Drawing.Imaging
[System.Windows.Forms.Application]::EnableVisualStyles()

# -----------------------------
# Constants / theme
# -----------------------------

$UI = @{
    Back        = [System.Drawing.Color]::FromArgb(30, 30, 34)
    Panel       = [System.Drawing.Color]::FromArgb(38, 38, 43)
    Panel2      = [System.Drawing.Color]::FromArgb(45, 45, 51)
    InputBack   = [System.Drawing.Color]::FromArgb(248, 248, 248)
    InputFore   = [System.Drawing.Color]::FromArgb(20, 20, 20)
    Text        = [System.Drawing.Color]::FromArgb(242, 242, 245)
    Muted       = [System.Drawing.Color]::FromArgb(180, 180, 188)
    Button      = [System.Drawing.Color]::FromArgb(74, 74, 84)
    ButtonHover = [System.Drawing.Color]::FromArgb(94, 94, 108)
    GridLine    = [System.Drawing.Color]::FromArgb(72, 72, 80)
    Accent      = [System.Drawing.Color]::FromArgb(174, 73, 210)
}

$PreviewSampleText = 'Aa Gg 0123  &!?  @#  $%  éñ  Ω  𝒢'

# -----------------------------
# Helpers
# -----------------------------

function Normalize-Key([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    return ($Text.ToLowerInvariant() -replace '[^a-z0-9]+', '')
}

function Normalize-Line([object]$Value) {
    if ($null -eq $Value) { return "" }
    $s = [string]$Value
    $s = $s -replace "(`r`n|`n|`r)+", " "
    $s = $s -replace "\s+", " "
    return $s.Trim()
}

function Color-To-Hex([System.Drawing.Color]$Color) {
    return "#{0:X2}{1:X2}{2:X2}" -f $Color.R, $Color.G, $Color.B
}

function Hex-To-Color([string]$Hex, [System.Drawing.Color]$Fallback) {
    try {
        $h = $Hex.Trim().TrimStart('#')
        if ($h -notmatch '^[0-9A-Fa-f]{6}$') { return $Fallback }
        return [System.Drawing.Color]::FromArgb(
            [Convert]::ToInt32($h.Substring(0,2),16),
            [Convert]::ToInt32($h.Substring(2,2),16),
            [Convert]::ToInt32($h.Substring(4,2),16)
        )
    }
    catch { return $Fallback }
}

function Color-To-Rgba([System.Drawing.Color]$Color, [int]$OpacityPercent) {
    $a = [math]::Round([math]::Max(0,[math]::Min(100,$OpacityPercent)) / 100, 2)
    return "rgba($($Color.R),$($Color.G),$($Color.B),$a)"
}

function Css-Font([string]$FontName) {
    if ([string]::IsNullOrWhiteSpace($FontName)) { return 'Arial, sans-serif' }
    if ($FontName -match '\s') { return '"' + $FontName.Replace('"','\"') + '", Arial, sans-serif' }
    return $FontName + ', Arial, sans-serif'
}

function Shuffle-Array([object[]]$Items) {
    $a = @($Items)
    for ($i = $a.Count - 1; $i -gt 0; $i--) {
        $j = Get-Random -Minimum 0 -Maximum ($i + 1)
        $tmp = $a[$i]
        $a[$i] = $a[$j]
        $a[$j] = $tmp
    }
    return ,$a
}

function Style-Button([System.Windows.Forms.Button]$Button) {
    $Button.UseVisualStyleBackColor = $false
    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(105,105,116)
    $Button.FlatAppearance.MouseOverBackColor = $UI.ButtonHover
    $Button.FlatAppearance.MouseDownBackColor = $UI.Accent
    $Button.BackColor = $UI.Button
    $Button.ForeColor = $UI.Text
    $Button.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $Button.AutoSize = $false
    $Button.Height = 30
}

function Style-CheckBox([System.Windows.Forms.CheckBox]$CheckBox) {
    $CheckBox.UseVisualStyleBackColor = $false
    $CheckBox.BackColor = [System.Drawing.Color]::Transparent
    $CheckBox.ForeColor = $UI.Text
    $CheckBox.AutoSize = $true
    $CheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $CheckBox.Padding = New-Object System.Windows.Forms.Padding(0,2,0,2)
    $CheckBox.Margin = New-Object System.Windows.Forms.Padding(5,5,10,5)
}

function Style-TextBox([System.Windows.Forms.TextBox]$TextBox) {
    $TextBox.BackColor = $UI.InputBack
    $TextBox.ForeColor = $UI.InputFore
    $TextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
}

function Style-Combo([System.Windows.Forms.ComboBox]$Combo) {
    $Combo.BackColor = $UI.InputBack
    $Combo.ForeColor = $UI.InputFore
    $Combo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Combo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
}

function Style-Num([System.Windows.Forms.NumericUpDown]$Num) {
    $Num.BackColor = $UI.InputBack
    $Num.ForeColor = $UI.InputFore
    $Num.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $Num.Font = New-Object System.Drawing.Font("Segoe UI", 9)
}

function New-UiLabel([string]$Text, [string]$Align = "MiddleRight") {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.ForeColor = $UI.Text
    $l.TextAlign = $Align
    $l.Dock = "Fill"
    $l.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    return $l
}

function New-Group([string]$Title, [int]$Height) {
    $g = New-Object System.Windows.Forms.GroupBox
    $g.Text = $Title
    $g.ForeColor = $UI.Text
    $g.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
    $g.Width = 452
    $g.Height = $Height
    $g.Margin = New-Object System.Windows.Forms.Padding(0,0,0,10)
    return $g
}

# -----------------------------
# Prompt definitions
# -----------------------------

$PromptSets = [ordered]@{
    "Game Notes" = @(
        "What do you always end up doing in this game even when it was not the plan?",
        "What mistake do YOU personally make repeatedly in this game?",
        "What game mechanic should chat remind you to use?",
        "What resource, ability, item, or system do you keep forgetting exists?",
        "What loot, collectible, or side objective do you refuse to leave behind?",
        "What is the actual progression goal of this playthrough right now?",
        "What specific thing is unusually satisfying when you pull it off?",
        "What should chat call out if you walk past or miss it?",
        "What does a genuinely good run / fight / round / mission look like?",
        "What part of the game makes you stop and overthink things?",
        "What should you remember to save / repair / reload / restock / equip?",
        "What enemy, boss, NPC, or mechanic keeps becoming a recurring problem?",
        "What kind of helpful backseating is actually useful in THIS game?",
        "What detail would immediately tell a new viewer what this run is about?"
    )
    "Chat & Engagement" = @(
        "What can chat productively call out while you play?",
        "What type of backseating is welcome, and what would actually help?",
        "What decision could chat weigh in on without taking over the run?",
        "What recurring goal should a new viewer understand quickly?",
        "What accomplishment from this run is worth telling new viewers?",
        "What should chat celebrate when you pull it off cleanly?",
        "What mistake has become obvious enough that chat should hold you accountable for it?",
        "What spoiler boundary applies to this game / run?",
        "What could a lurker still react to without needing full context?",
        "What game-specific thing should viewers remind you about during long sessions?"
    )
    "Stream In-Jokes" = @(
        "Who are you lusting for in this game?",
        "What in this game would send you directly to horny jail?",
        "Who gets the strongest 'hear me out' treatment?",
        "What has chat roasted you for repeatedly in this game?",
        "What mechanic makes you way more confident than you should be?",
        "What repeated failure has started becoming a bit?",
        "Has chat given a character, enemy, item, or location a dumb nickname?",
        "What would be the most 'Gabisness' way to solve a problem in this game?",
        "What game-specific adult/PPV joke could ONLY belong to this game?",
        "What unique bit has emerged from THIS playthrough that you want preserved?"
    )
    "Reminders & CTAs" = @(
        "Write a hydration reminder that references something specific in this game.",
        "Write a posture / stretch reminder that fits this game.",
        "What long-session reminder would genuinely help you while playing this?",
        "What should viewers remind you to check before a boss / match / mission / run?",
        "Write a natural subscribe CTA that fits the current stream goal.",
        "Write a membership CTA that feels specific to the Gab-lings / community.",
        "What should chat say when you start getting tilted, greedy, distracted, or tunnel-visioned?",
        "What food / break / rest reminder fits this game or this type of stream?"
    )
    "Oddballs" = @(
        "", "", "", "", "", "", "", "", "", "", "", ""
    )
}

$SiteRows = @(
    [pscustomobject]@{ Link="gabisness.com/rules"; Prompt="Rules #1 — Make the chat-conduct plug feel native to this game's world or mechanics." },
    [pscustomobject]@{ Link="gabisness.com/rules"; Prompt="Rules #2 — Use a completely different game-specific reason to point people to the rules." },

    [pscustomobject]@{ Link="gabisness.com/games"; Prompt="Games #1 — Tie the recent-games list to this game's missions, worlds, quests, runs, etc." },
    [pscustomobject]@{ Link="gabisness.com/games"; Prompt="Games #2 — Why might someone watching THIS game care about the rest of your rotation?" },

    [pscustomobject]@{ Link="gabisness.com/schedule"; Prompt="Schedule #1 — Frame the next stream/session in language that fits this game." },
    [pscustomobject]@{ Link="gabisness.com/schedule"; Prompt="Schedule #2 — Use another game-specific angle for when viewers can catch you next." },

    [pscustomobject]@{ Link="gabisness.com/setup"; Prompt="Setup #1 — Connect your PC/stream setup to something visually or mechanically specific here." },
    [pscustomobject]@{ Link="gabisness.com/setup"; Prompt="Setup #2 — Plug the hardware page without just saying 'my setup is here'." },

    [pscustomobject]@{ Link="gabisness.com/playlists"; Prompt="Playlists #1 — Connect your playlists to travel, grinding, menus, downtime, ambience, etc." },
    [pscustomobject]@{ Link="gabisness.com/playlists"; Prompt="Playlists #2 — Find a second, different music-related situation from this game." },

    [pscustomobject]@{ Link="gabisness.com/donate"; Prompt="Donate #1 — Tie direct support to the current run, challenge, project, or stream." },
    [pscustomobject]@{ Link="gabisness.com/donate"; Prompt="Donate #2 — Find another support angle that is NOT a paraphrase of the first." },

    [pscustomobject]@{ Link="gabisness.com/suggest"; Prompt="Suggest #1 — Connect game suggestions to what you are currently doing or what comes next." },
    [pscustomobject]@{ Link="gabisness.com/suggest"; Prompt="Suggest #2 — Give viewers a second reason to submit a future game." },

    [pscustomobject]@{ Link="gabisness.com/faq"; Prompt="FAQ #1 — What recurring viewer question could naturally point people to the FAQ?" },
    [pscustomobject]@{ Link="gabisness.com/faq"; Prompt="FAQ #2 — Give the FAQ a game-specific framing without making it sound like a corporate help center." },

    [pscustomobject]@{ Link="gabisness.com/contact"; Prompt="Contact #1 — Work in that /contact has your links and PO box in a way relevant to this game/stream." },
    [pscustomobject]@{ Link="gabisness.com/contact"; Prompt="Contact #2 — Work in the outreach/contact form for collabs, sponsors, or messages without generic ad copy." },

    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Store #1 — General store plug. Keep this distinct from any specific shirt/hat/etc. merch prompt." },
    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Store #2 — Another general shop line tied to this game's experience or aesthetic." },

    [pscustomobject]@{ Link="onlyfans.com/gabisnessppv"; Prompt="PPV #1 — Make the adult/PPV plug specific enough that it could only belong to this game." },
    [pscustomobject]@{ Link="onlyfans.com/gabisnessppv"; Prompt="PPV #2 — Use a genuinely different character/mechanic/location reference for the second PPV plug." }
)

$MerchRows = @(
    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Shirts #1 — What game-specific shirt plug could fit naturally into this ticker?" },
    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Shirts #2 — Find a different hook for shirts instead of rewording the first." },

    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Pants #1 — How could pants/bottoms become a relevant plug for this game's movement, outfit, armor, etc.?" },
    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Pants #2 — A second pants/bottoms line with a genuinely different game reference." },

    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Hats #1 — Connect hats/headwear to something recognizable in this game." },
    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Hats #2 — Find another headwear angle that does not repeat the first." },

    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Clothes #1 — General apparel plug using this game's fashion, armor, uniforms, costumes, etc." },
    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Clothes #2 — A second broad clothing plug from another angle." },

    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Eddy's Sinister Creations #1 — Plug the hand-made art line by Eddy / Sinister Sigster using a game-relevant art/crafting reference." },
    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Eddy's Sinister Creations #2 — Another handmade-art plug that feels distinct and specific." },

    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Store #1 — Broad merch/store prompt for something that does not fit one category." },
    [pscustomobject]@{ Link="gabisness.com/store"; Prompt="Store #2 — A second broad store line, ideally using a different part of this game's vibe." }
)

# -----------------------------
# State
# -----------------------------

$script:Grids = [ordered]@{}
$script:TextColor = [System.Drawing.Color]::FromArgb(245,245,245)
$script:BgColor1 = [System.Drawing.Color]::FromArgb(28,28,32)
$script:BgColor2 = [System.Drawing.Color]::FromArgb(75,45,95)
$script:BorderColor = [System.Drawing.Color]::White

$script:PreviewMode = "text"
$script:LogoImage = $null
$script:LogoPath = ""
$script:AnimationActive = $false
$script:AnimationStage = "idle"
$script:AnimationX = 0.0
$script:AnimationAlpha = 1.0
$script:AnimationSlideWidth = 0.0
$script:AnimationStartX = 0.0
$script:AnimationWatch = [System.Diagnostics.Stopwatch]::New()

# -----------------------------
# Main form
# -----------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Gabisness OBS Ticker Builder v2"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(1510, 930)
$form.MinimumSize = New-Object System.Drawing.Size(1240, 760)
$form.BackColor = $UI.Back
$form.ForeColor = $UI.Text
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi

# -----------------------------
# Header
# -----------------------------

$header = New-Object System.Windows.Forms.TableLayoutPanel
$header.Dock = "Top"
$header.Height = 94
$header.ColumnCount = 10
$header.RowCount = 2
$header.Padding = New-Object System.Windows.Forms.Padding(10,8,10,5)
$header.BackColor = $UI.Panel

$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,85)))
$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,27)))
$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,55)))
$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,17)))
$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,105)))
$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,23)))
$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,80)))
$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,14)))
$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,75)))
$header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,105)))

$txtGame = New-Object System.Windows.Forms.TextBox
$txtKey = New-Object System.Windows.Forms.TextBox
$txtFile = New-Object System.Windows.Forms.TextBox
$txtTwitch = New-Object System.Windows.Forms.TextBox
foreach ($tb in @($txtGame,$txtKey,$txtFile,$txtTwitch)) { Style-TextBox $tb; $tb.Dock = "Fill" }

$chkVisible = New-Object System.Windows.Forms.CheckBox
$chkVisible.Text = "Visible"
$chkVisible.Checked = $true
Style-CheckBox $chkVisible
$visibleHost = New-Object System.Windows.Forms.FlowLayoutPanel
$visibleHost.Dock = "Fill"
$visibleHost.FlowDirection = "LeftToRight"
$visibleHost.WrapContents = $false
$visibleHost.Controls.Add($chkVisible)

$btnFilename = New-Object System.Windows.Forms.Button
$btnFilename.Text = "From key"
$btnFilename.Dock = "Fill"
Style-Button $btnFilename

$header.Controls.Add((New-UiLabel "Game"),0,0); $header.Controls.Add($txtGame,1,0)
$header.Controls.Add((New-UiLabel "Key"),2,0); $header.Controls.Add($txtKey,3,0)
$header.Controls.Add((New-UiLabel "Messages file"),4,0); $header.Controls.Add($txtFile,5,0)
$header.Controls.Add((New-UiLabel "Twitch ID"),6,0); $header.Controls.Add($txtTwitch,7,0)
$header.Controls.Add($visibleHost,8,0); $header.Controls.Add($btnFilename,9,0)

$headerHint = New-Object System.Windows.Forms.Label
$headerHint.Text = "Game = picker label   •   Key = JSON / automation key   •   Messages file = exact TXT filename   •   Twitch ID = category reference"
$headerHint.ForeColor = $UI.Muted
$headerHint.TextAlign = "MiddleLeft"
$headerHint.Dock = "Fill"
$headerHint.Font = New-Object System.Drawing.Font("Segoe UI",8.5)
$header.SetColumnSpan($headerHint,10)
$header.Controls.Add($headerHint,0,1)

$form.Controls.Add($header)

# -----------------------------
# Split area
# -----------------------------

$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock = "Fill"
$split.Orientation = [System.Windows.Forms.Orientation]::Vertical
$split.SplitterDistance = 1000
$split.Panel1MinSize = 720
$split.Panel2MinSize = 410
$split.BackColor = $UI.Back
$form.Controls.Add($split)
$split.BringToFront()

# -----------------------------
# Left: tabs + compiler
# -----------------------------

$leftLayout = New-Object System.Windows.Forms.TableLayoutPanel
$leftLayout.Dock = "Fill"
$leftLayout.ColumnCount = 1
$leftLayout.RowCount = 2
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,62)))
$split.Panel1.Controls.Add($leftLayout)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = "Fill"
$tabs.Font = New-Object System.Drawing.Font("Segoe UI",9)
$leftLayout.Controls.Add($tabs,0,0)

function New-PromptGrid {
    param(
        [string]$Name,
        [object[]]$Rows,
        [bool]$WithCopyButton = $false
    )

    $page = New-Object System.Windows.Forms.TabPage
    $page.Text = $Name
    $page.BackColor = $UI.Back
    $page.ForeColor = $UI.Text

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = "Fill"
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $true
    $grid.RowHeadersVisible = $false
    $grid.AutoSizeRowsMode = [System.Windows.Forms.DataGridViewAutoSizeRowsMode]::AllCells
    $grid.BackgroundColor = $UI.Back
    $grid.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $grid.GridColor = $UI.GridLine
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $UI.Panel2
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $UI.Text
    $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI Semibold",9)
    $grid.ColumnHeadersHeight = 30
    $grid.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(36,36,40)
    $grid.DefaultCellStyle.ForeColor = $UI.Text
    $grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(68,77,106)
    $grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI",9)

    $promptCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $promptCol.Name = "Prompt"
    $promptCol.HeaderText = "Prompt"
    $promptCol.ReadOnly = $true
    $promptCol.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
    $promptCol.FillWeight = $(if ($WithCopyButton) { 42 } else { 45 })
    $promptCol.DefaultCellStyle.WrapMode = [System.Windows.Forms.DataGridViewTriState]::True
    $promptCol.DefaultCellStyle.BackColor = $UI.Panel
    $promptCol.DefaultCellStyle.ForeColor = $UI.Text
    [void]$grid.Columns.Add($promptCol)

    if ($WithCopyButton) {
        $copyCol = New-Object System.Windows.Forms.DataGridViewButtonColumn
        $copyCol.Name = "CopyLink"
        $copyCol.HeaderText = "Link"
        $copyCol.Text = "Copy link"
        $copyCol.UseColumnTextForButtonValue = $true
        $copyCol.Width = 82
        $copyCol.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::None
        $copyCol.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $copyCol.DefaultCellStyle.BackColor = $UI.Button
        $copyCol.DefaultCellStyle.ForeColor = $UI.Text
        $copyCol.DefaultCellStyle.SelectionBackColor = $UI.Accent
        $copyCol.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
        [void]$grid.Columns.Add($copyCol)
    }

    $lineCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $lineCol.Name = "Line"
    $lineCol.HeaderText = "Your ticker line"
    $lineCol.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
    $lineCol.FillWeight = $(if ($WithCopyButton) { 58 } else { 55 })
    $lineCol.DefaultCellStyle.WrapMode = [System.Windows.Forms.DataGridViewTriState]::True
    $lineCol.DefaultCellStyle.BackColor = $UI.InputBack
    $lineCol.DefaultCellStyle.ForeColor = $UI.InputFore
    $lineCol.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(210,225,255)
    $lineCol.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black
    [void]$grid.Columns.Add($lineCol)

    $n = 1
    foreach ($rowDef in $Rows) {
        if ($WithCopyButton) {
            $prompt = [string]$rowDef.Prompt
            $link = [string]$rowDef.Link
            $index = $grid.Rows.Add($prompt,"","")
            $grid.Rows[$index].Tag = $link
        }
        else {
            $prompt = [string]$rowDef
            if ([string]::IsNullOrWhiteSpace($prompt)) { $prompt = "Extra line $n" }
            [void]$grid.Rows.Add($prompt,"")
        }
        $n++
    }

    if ($WithCopyButton) {
        $grid.Add_CellContentClick({
            param($sender,$e)
            if ($e.RowIndex -lt 0) { return }
            if ($sender.Columns[$e.ColumnIndex].Name -ne "CopyLink") { return }
            $link = [string]$sender.Rows[$e.RowIndex].Tag
            if (-not [string]::IsNullOrWhiteSpace($link)) {
                [System.Windows.Forms.Clipboard]::SetText($link)
                $script:StatusLabel.Text = "Copied: $link"
            }
        })
    }

    $grid.Add_CellValueChanged({ Update-LineCount })
    $page.Controls.Add($grid)
    [void]$tabs.TabPages.Add($page)
    $script:Grids[$Name] = $grid
}

foreach ($entry in $PromptSets.GetEnumerator()) {
    New-PromptGrid -Name $entry.Key -Rows $entry.Value
}
New-PromptGrid -Name "Site Plugs" -Rows $SiteRows -WithCopyButton $true
New-PromptGrid -Name "Merch Plugs" -Rows $MerchRows -WithCopyButton $true

# Reorder tabs so plugs sit together before reminders/oddballs.
$desiredOrder = @("Game Notes","Chat & Engagement","Stream In-Jokes","Site Plugs","Merch Plugs","Reminders & CTAs","Oddballs")
foreach ($name in $desiredOrder) {
    foreach ($page in @($tabs.TabPages)) {
        if ($page.Text -eq $name) {
            $tabs.TabPages.Remove($page)
            [void]$tabs.TabPages.Add($page)
            break
        }
    }
}

$compilerBar = New-Object System.Windows.Forms.FlowLayoutPanel
$compilerBar.Dock = "Fill"
$compilerBar.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$compilerBar.WrapContents = $false
$compilerBar.AutoScroll = $true
$compilerBar.Padding = New-Object System.Windows.Forms.Padding(10,10,8,6)
$compilerBar.BackColor = $UI.Panel

$lblCount = New-Object System.Windows.Forms.Label
$lblCount.Text = "0 / 50 lines"
$lblCount.AutoSize = $true
$lblCount.ForeColor = $UI.Text
$lblCount.Font = New-Object System.Drawing.Font("Segoe UI Semibold",10)
$lblCount.Margin = New-Object System.Windows.Forms.Padding(4,8,16,0)

$chkDedupe = New-Object System.Windows.Forms.CheckBox
$chkDedupe.Text = "Remove exact duplicates"
$chkDedupe.Checked = $true
Style-CheckBox $chkDedupe

$chkShuffle = New-Object System.Windows.Forms.CheckBox
$chkShuffle.Text = "Shuffle compiled TXT"
Style-CheckBox $chkShuffle

$chkRequire50 = New-Object System.Windows.Forms.CheckBox
$chkRequire50.Text = "Require exactly 50"
Style-CheckBox $chkRequire50

$btnCompile = New-Object System.Windows.Forms.Button
$btnCompile.Text = "Compile TXT..."
$btnCompile.Width = 112
Style-Button $btnCompile

$btnCopyLines = New-Object System.Windows.Forms.Button
$btnCopyLines.Text = "Copy lines"
$btnCopyLines.Width = 92
Style-Button $btnCopyLines

$script:StatusLabel = New-Object System.Windows.Forms.Label
$script:StatusLabel.Text = ""
$script:StatusLabel.AutoSize = $true
$script:StatusLabel.ForeColor = $UI.Muted
$script:StatusLabel.Margin = New-Object System.Windows.Forms.Padding(12,8,0,0)

$compilerBar.Controls.AddRange(@($lblCount,$chkDedupe,$chkShuffle,$chkRequire50,$btnCompile,$btnCopyLines,$script:StatusLabel))
$leftLayout.Controls.Add($compilerBar,0,1)

# -----------------------------
# Right panel
# -----------------------------

$right = New-Object System.Windows.Forms.Panel
$right.Dock = "Fill"
$right.AutoScroll = $true
$right.BackColor = $UI.Back
$split.Panel2.Controls.Add($right)

$rightFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$rightFlow.Dock = "Top"
$rightFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$rightFlow.WrapContents = $false
$rightFlow.AutoSize = $true
$rightFlow.Padding = New-Object System.Windows.Forms.Padding(10)
$rightFlow.BackColor = $UI.Back
$right.Controls.Add($rightFlow)

# Appearance
$appearanceGroup = New-Group "Ticker appearance" 280
$rightFlow.Controls.Add($appearanceGroup)

$appearanceTable = New-Object System.Windows.Forms.TableLayoutPanel
$appearanceTable.Dock = "Fill"
$appearanceTable.Padding = New-Object System.Windows.Forms.Padding(8,10,8,8)
$appearanceTable.ColumnCount = 2
$appearanceTable.RowCount = 8
$appearanceTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,130)))
$appearanceTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100)))
$appearanceGroup.Controls.Add($appearanceTable)

$cmbFont = New-Object System.Windows.Forms.ComboBox
$cmbFont.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
Style-Combo $cmbFont
$cmbFont.Dock = "Fill"

$fontCollection = New-Object System.Drawing.Text.InstalledFontCollection
$fontNames = @($fontCollection.Families | ForEach-Object Name | Sort-Object -Unique)
[void]$cmbFont.Items.AddRange([object[]]$fontNames)
if ($cmbFont.Items.Contains("Segoe UI")) { $cmbFont.SelectedItem = "Segoe UI" }
elseif ($cmbFont.Items.Count -gt 0) { $cmbFont.SelectedIndex = 0 }

$nudSize = New-Object System.Windows.Forms.NumericUpDown
$nudSize.Minimum=12; $nudSize.Maximum=200; $nudSize.Value=30; Style-Num $nudSize; $nudSize.Dock="Fill"

$nudSpeed = New-Object System.Windows.Forms.NumericUpDown
$nudSpeed.Minimum=20; $nudSpeed.Maximum=2000; $nudSpeed.Value=158; Style-Num $nudSpeed; $nudSpeed.Dock="Fill"

$nudCollapse = New-Object System.Windows.Forms.NumericUpDown
$nudCollapse.Minimum=0; $nudCollapse.Maximum=3600000; $nudCollapse.Increment=1000; $nudCollapse.Value=510000; Style-Num $nudCollapse; $nudCollapse.Dock="Fill"

$nudFade = New-Object System.Windows.Forms.NumericUpDown
$nudFade.Minimum=0; $nudFade.Maximum=60000; $nudFade.Value=470; Style-Num $nudFade; $nudFade.Dock="Fill"

$nudGap = New-Object System.Windows.Forms.NumericUpDown
$nudGap.Minimum=0; $nudGap.Maximum=200; $nudGap.Value=14; Style-Num $nudGap; $nudGap.Dock="Fill"

$txtLogo = New-Object System.Windows.Forms.TextBox
$txtLogo.Text = "justG.png"
Style-TextBox $txtLogo
$txtLogo.Dock = "Fill"

$chkRules = New-Object System.Windows.Forms.CheckBox
$chkRules.Text = "Show top / bottom rule"
$chkRules.Checked = $true
Style-CheckBox $chkRules
$rulesHost = New-Object System.Windows.Forms.FlowLayoutPanel
$rulesHost.Dock = "Fill"; $rulesHost.WrapContents=$false; $rulesHost.Controls.Add($chkRules)

$appearanceRows = @(
    @("System font",$cmbFont),
    @("Text size",$nudSize),
    @("Speed (px/s)",$nudSpeed),
    @("Collapse ms",$nudCollapse),
    @("Fade ms",$nudFade),
    @("Gap",$nudGap),
    @("Logo filename",$txtLogo),
    @("Rules",$rulesHost)
)
for($i=0;$i -lt $appearanceRows.Count;$i++){
    $appearanceTable.Controls.Add((New-UiLabel $appearanceRows[$i][0]),0,$i)
    $appearanceTable.Controls.Add($appearanceRows[$i][1],1,$i)
}

# Colors
$colorsGroup = New-Group "Colors" 225
$rightFlow.Controls.Add($colorsGroup)

$colorTable = New-Object System.Windows.Forms.TableLayoutPanel
$colorTable.Dock="Fill"
$colorTable.Padding=New-Object System.Windows.Forms.Padding(8,10,8,8)
$colorTable.ColumnCount=3
$colorTable.RowCount=6
$colorTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,110)))
$colorTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100)))
$colorTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,78)))
$colorsGroup.Controls.Add($colorTable)

function Add-ColorRow([int]$Row,[string]$Label,[System.Drawing.Color]$Initial) {
    $box=New-Object System.Windows.Forms.TextBox
    $box.Text=Color-To-Hex $Initial
    Style-TextBox $box
    $box.Dock="Fill"

    $button=New-Object System.Windows.Forms.Button
    $button.Text="Pick"
    $button.BackColor=$Initial
    $button.ForeColor=$UI.Text
    Style-Button $button
    $button.Dock="Fill"

    $colorTable.Controls.Add((New-UiLabel $Label),0,$Row)
    $colorTable.Controls.Add($box,1,$Row)
    $colorTable.Controls.Add($button,2,$Row)
    return @($box,$button)
}

$fgRow=Add-ColorRow 0 "Text" $script:TextColor
$bg1Row=Add-ColorRow 1 "Background 1" $script:BgColor1
$bg2Row=Add-ColorRow 2 "Background 2" $script:BgColor2
$borderRow=Add-ColorRow 3 "Border" $script:BorderColor
$txtFg=$fgRow[0];$btnFg=$fgRow[1]
$txtBg1=$bg1Row[0];$btnBg1=$bg1Row[1]
$txtBg2=$bg2Row[0];$btnBg2=$bg2Row[1]
$txtBorder=$borderRow[0];$btnBorder=$borderRow[1]

$chkGradient=New-Object System.Windows.Forms.CheckBox
$chkGradient.Text="Use horizontal gradient"
$chkGradient.Checked=$true
Style-CheckBox $chkGradient
$gradientHost=New-Object System.Windows.Forms.FlowLayoutPanel
$gradientHost.Dock="Fill";$gradientHost.WrapContents=$false;$gradientHost.Controls.Add($chkGradient)

$nudOpacity=New-Object System.Windows.Forms.NumericUpDown
$nudOpacity.Minimum=10;$nudOpacity.Maximum=100;$nudOpacity.Value=96
Style-Num $nudOpacity;$nudOpacity.Dock="Fill"

$colorTable.Controls.Add((New-UiLabel "Background"),0,4)
$colorTable.Controls.Add($gradientHost,1,4);$colorTable.SetColumnSpan($gradientHost,2)
$colorTable.Controls.Add((New-UiLabel "Opacity %"),0,5)
$colorTable.Controls.Add($nudOpacity,1,5);$colorTable.SetColumnSpan($nudOpacity,2)

# Preview
$previewGroup = New-Group "Preview" 265
$rightFlow.Controls.Add($previewGroup)

$previewPanel=New-Object System.Windows.Forms.Panel
$previewPanel.Location=New-Object System.Drawing.Point(12,26)
$previewPanel.Size=New-Object System.Drawing.Size(418,140)
$previewPanel.BackColor=$UI.Panel
$previewPanel.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle
$previewGroup.Controls.Add($previewPanel)

$btnSwap=New-Object System.Windows.Forms.Button
$btnSwap.Text="Swap text/image"
$btnSwap.Location=New-Object System.Drawing.Point(12,176)
$btnSwap.Size=New-Object System.Drawing.Size(128,32)
Style-Button $btnSwap
$previewGroup.Controls.Add($btnSwap)

$btnAnimate=New-Object System.Windows.Forms.Button
$btnAnimate.Text="Play animation"
$btnAnimate.Location=New-Object System.Drawing.Point(150,176)
$btnAnimate.Size=New-Object System.Drawing.Size(128,32)
Style-Button $btnAnimate
$previewGroup.Controls.Add($btnAnimate)

$lblPreviewMode=New-Object System.Windows.Forms.Label
$lblPreviewMode.Text="Static preview: text"
$lblPreviewMode.ForeColor=$UI.Muted
$lblPreviewMode.Location=New-Object System.Drawing.Point(290,181)
$lblPreviewMode.Size=New-Object System.Drawing.Size(140,22)
$lblPreviewMode.TextAlign="MiddleRight"
$previewGroup.Controls.Add($lblPreviewMode)

$lblAnimNote=New-Object System.Windows.Forms.Label
$lblAnimNote.Text="Animation previews one full scroll + fade. The long collapse wait is intentionally skipped."
$lblAnimNote.ForeColor=$UI.Muted
$lblAnimNote.Location=New-Object System.Drawing.Point(12,214)
$lblAnimNote.Size=New-Object System.Drawing.Size(418,36)
$previewGroup.Controls.Add($lblAnimNote)

# Output
$outputGroup=New-Group "Preset / project" 190
$rightFlow.Controls.Add($outputGroup)

$btnCopyJson=New-Object System.Windows.Forms.Button
$btnCopyJson.Text="Copy JSON entry";$btnCopyJson.Location=New-Object System.Drawing.Point(12,28);$btnCopyJson.Size=New-Object System.Drawing.Size(200,34);Style-Button $btnCopyJson
$outputGroup.Controls.Add($btnCopyJson)

$btnSaveJson=New-Object System.Windows.Forms.Button
$btnSaveJson.Text="Save JSON entry...";$btnSaveJson.Location=New-Object System.Drawing.Point(220,28);$btnSaveJson.Size=New-Object System.Drawing.Size(210,34);Style-Button $btnSaveJson
$outputGroup.Controls.Add($btnSaveJson)

$btnSaveProject=New-Object System.Windows.Forms.Button
$btnSaveProject.Text="Save draft...";$btnSaveProject.Location=New-Object System.Drawing.Point(12,72);$btnSaveProject.Size=New-Object System.Drawing.Size(200,34);Style-Button $btnSaveProject
$outputGroup.Controls.Add($btnSaveProject)

$btnLoadProject=New-Object System.Windows.Forms.Button
$btnLoadProject.Text="Load draft...";$btnLoadProject.Location=New-Object System.Drawing.Point(220,72);$btnLoadProject.Size=New-Object System.Drawing.Size(210,34);Style-Button $btnLoadProject
$outputGroup.Controls.Add($btnLoadProject)

$outputNote=New-Object System.Windows.Forms.Label
$outputNote.Location=New-Object System.Drawing.Point(12,118)
$outputNote.Size=New-Object System.Drawing.Size(418,58)
$outputNote.Text="JSON includes visible immediately after src, plus twitchGameId and borderColor. borderColor needs the small index.html patch described in the README."
$outputNote.ForeColor=$UI.Muted
$outputGroup.Controls.Add($outputNote)

# -----------------------------
# Line/data helpers
# -----------------------------

function Get-AllLines {
    $list=New-Object System.Collections.Generic.List[string]
    foreach($grid in $script:Grids.Values){
        foreach($row in $grid.Rows){
            $line=Normalize-Line $row.Cells["Line"].Value
            if(-not [string]::IsNullOrWhiteSpace($line)){ $list.Add($line) }
        }
    }
    $result=@($list)
    if($chkDedupe.Checked){
        $seen=@{}
        $unique=New-Object System.Collections.Generic.List[string]
        foreach($line in $result){
            $k=$line.ToLowerInvariant()
            if(-not $seen.ContainsKey($k)){ $seen[$k]=$true;$unique.Add($line) }
        }
        $result=@($unique)
    }
    return ,$result
}

function Update-LineCount {
    $count=@(Get-AllLines).Count
    $lblCount.Text="$count / 50 lines"
    if($count -eq 50){$lblCount.ForeColor=[System.Drawing.Color]::LightGreen}
    elseif($count -gt 50){$lblCount.ForeColor=[System.Drawing.Color]::Salmon}
    else{$lblCount.ForeColor=$UI.Text}
}

function Sync-Colors {
    $script:TextColor=Hex-To-Color $txtFg.Text $script:TextColor
    $script:BgColor1=Hex-To-Color $txtBg1.Text $script:BgColor1
    $script:BgColor2=Hex-To-Color $txtBg2.Text $script:BgColor2
    $script:BorderColor=Hex-To-Color $txtBorder.Text $script:BorderColor
    $btnFg.BackColor=$script:TextColor
    $btnBg1.BackColor=$script:BgColor1
    $btnBg2.BackColor=$script:BgColor2
    $btnBorder.BackColor=$script:BorderColor
    $previewPanel.Invalidate()
}

function Pick-Color([string]$Which){
    $dlg=New-Object System.Windows.Forms.ColorDialog
    switch($Which){
        "fg" {$dlg.Color=$script:TextColor}
        "bg1" {$dlg.Color=$script:BgColor1}
        "bg2" {$dlg.Color=$script:BgColor2}
        "border" {$dlg.Color=$script:BorderColor}
    }
    if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        switch($Which){
            "fg" {$script:TextColor=$dlg.Color;$txtFg.Text=Color-To-Hex $dlg.Color}
            "bg1" {$script:BgColor1=$dlg.Color;$txtBg1.Text=Color-To-Hex $dlg.Color}
            "bg2" {$script:BgColor2=$dlg.Color;$txtBg2.Text=Color-To-Hex $dlg.Color}
            "border" {$script:BorderColor=$dlg.Color;$txtBorder.Text=Color-To-Hex $dlg.Color}
        }
        Sync-Colors
    }
}

function Get-BackgroundCss {
    $a=Color-To-Rgba $script:BgColor1 ([int]$nudOpacity.Value)
    if($chkGradient.Checked){
        $b=Color-To-Rgba $script:BgColor2 ([int]$nudOpacity.Value)
        return "linear-gradient(90deg,$a,$b)"
    }
    return $a
}

function Get-PresetObject {
    Sync-Colors
    $key=Normalize-Key $txtKey.Text
    if([string]::IsNullOrWhiteSpace($key)){$key=Normalize-Key $txtGame.Text}
    $label=$txtGame.Text.Trim()
    if([string]::IsNullOrWhiteSpace($label)){$label=$key}
    $src=$txtFile.Text.Trim()
    if([string]::IsNullOrWhiteSpace($src)){$src="messages$key.txt"}

    return [ordered]@{
        key=$key
        label=$label
        src=$src
        visible=[bool]$chkVisible.Checked
        twitchGameId=$txtTwitch.Text.Trim()
        bg=Get-BackgroundCss
        fg=Color-To-Hex $script:TextColor
        borderColor=Color-To-Hex $script:BorderColor
        size=[int]$nudSize.Value
        speed=[int]$nudSpeed.Value
        logo=$txtLogo.Text.Trim()
        collapse=[int]$nudCollapse.Value
        fadeMs=[int]$nudFade.Value
        gap=[int]$nudGap.Value
        rules=$(if($chkRules.Checked){"1"}else{"0"})
        font=Css-Font ([string]$cmbFont.SelectedItem)
    }
}

# -----------------------------
# Draft persistence
# -----------------------------

function Get-DraftObject {
    $lineData=[ordered]@{}
    foreach($name in $script:Grids.Keys){
        $vals=@()
        foreach($row in $script:Grids[$name].Rows){$vals+=Normalize-Line $row.Cells["Line"].Value}
        $lineData[$name]=$vals
    }
    return [ordered]@{
        version=2
        game=$txtGame.Text
        key=$txtKey.Text
        file=$txtFile.Text
        twitchGameId=$txtTwitch.Text
        visible=[bool]$chkVisible.Checked
        font=[string]$cmbFont.SelectedItem
        size=[int]$nudSize.Value
        speed=[int]$nudSpeed.Value
        collapse=[int]$nudCollapse.Value
        fadeMs=[int]$nudFade.Value
        gap=[int]$nudGap.Value
        logo=$txtLogo.Text
        rules=[bool]$chkRules.Checked
        fg=$txtFg.Text
        bg1=$txtBg1.Text
        bg2=$txtBg2.Text
        border=$txtBorder.Text
        gradient=[bool]$chkGradient.Checked
        opacity=[int]$nudOpacity.Value
        lines=$lineData
    }
}

function Apply-DraftObject($d){
    $txtGame.Text=[string]$d.game
    $txtKey.Text=[string]$d.key
    $txtFile.Text=[string]$d.file
    $txtTwitch.Text=[string]$d.twitchGameId
    $chkVisible.Checked=[bool]$d.visible

    if($d.font -and $cmbFont.Items.Contains([string]$d.font)){$cmbFont.SelectedItem=[string]$d.font}
    if($d.size){$nudSize.Value=[decimal]$d.size}
    if($d.speed){$nudSpeed.Value=[decimal]$d.speed}
    if($null -ne $d.collapse){$nudCollapse.Value=[decimal]$d.collapse}
    if($null -ne $d.fadeMs){$nudFade.Value=[decimal]$d.fadeMs}
    if($null -ne $d.gap){$nudGap.Value=[decimal]$d.gap}
    if($d.logo){$txtLogo.Text=[string]$d.logo}
    $chkRules.Checked=[bool]$d.rules
    if($d.fg){$txtFg.Text=[string]$d.fg}
    if($d.bg1){$txtBg1.Text=[string]$d.bg1}
    if($d.bg2){$txtBg2.Text=[string]$d.bg2}
    if($d.border){$txtBorder.Text=[string]$d.border}
    $chkGradient.Checked=[bool]$d.gradient
    if($d.opacity){$nudOpacity.Value=[decimal]$d.opacity}

    if($d.lines){
        foreach($name in $script:Grids.Keys){
            $saved=$d.lines.$name
            if($null -eq $saved){continue}
            $arr=@($saved)
            $grid=$script:Grids[$name]
            for($i=0;$i -lt $grid.Rows.Count;$i++){
                $grid.Rows[$i].Cells["Line"].Value=$(if($i -lt $arr.Count){[string]$arr[$i]}else{""})
            }
        }
    }
    Sync-Colors
    Update-LineCount
}

# -----------------------------
# Logo loading
# -----------------------------

function Dispose-Logo {
    if($null -ne $script:LogoImage){
        try{$script:LogoImage.Dispose()}catch{}
        $script:LogoImage=$null
    }
    $script:LogoPath=""
}

function Load-Logo {
    $name=$txtLogo.Text.Trim()
    if([string]::IsNullOrWhiteSpace($name)){Dispose-Logo;return $false}
    $path=Join-Path -Path $PSScriptRoot -ChildPath $name
    if(-not (Test-Path -LiteralPath $path)){Dispose-Logo;return $false}
    if($script:LogoPath -eq $path -and $null -ne $script:LogoImage){return $true}

    Dispose-Logo
    try{
        $stream=[System.IO.File]::OpenRead($path)
        try{
            $img=[System.Drawing.Image]::FromStream($stream)
            try{$script:LogoImage=New-Object System.Drawing.Bitmap $img}
            finally{$img.Dispose()}
        }
        finally{$stream.Dispose()}
        $script:LogoPath=$path
        return $true
    }
    catch{
        Dispose-Logo
        return $false
    }
}

function Get-PreviewFont {
    $name=[string]$cmbFont.SelectedItem
    if([string]::IsNullOrWhiteSpace($name)){$name="Segoe UI"}
    $px=[single][int]$nudSize.Value
    try{
        return New-Object System.Drawing.Font -ArgumentList @($name,$px,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    }
    catch{
        return New-Object System.Drawing.Font -ArgumentList @("Segoe UI",$px,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    }
}

# -----------------------------
# Preview / animation painting
# -----------------------------

function Alpha-Color([System.Drawing.Color]$Color,[double]$Alpha,[double]$Opacity=1.0){
    $a=[int][math]::Round(255*[math]::Max(0,[math]::Min(1,$Alpha*$Opacity)))
    return [System.Drawing.Color]::FromArgb($a,$Color.R,$Color.G,$Color.B)
}

function Draw-ScaledImageCentered($Graphics,$Image,$Bounds,[int]$TargetHeight){
    if($null -eq $Image){return}
    $h=[math]::Min($TargetHeight,$Bounds.Height-12)
    $w=[int][math]::Round($Image.Width*($h/[double]$Image.Height))
    if($w -gt $Bounds.Width-20){
        $w=$Bounds.Width-20
        $h=[int][math]::Round($Image.Height*($w/[double]$Image.Width))
    }
    $x=$Bounds.X+[int](($Bounds.Width-$w)/2)
    $y=$Bounds.Y+[int](($Bounds.Height-$h)/2)
    $Graphics.DrawImage($Image,$x,$y,$w,$h)
}

$previewPanel.Add_Paint({
    param($sender,$e)
    Sync-Colors

    $g=$e.Graphics
    $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $rect=New-Object System.Drawing.Rectangle(0,0,[math]::Max(1,$previewPanel.ClientSize.Width-1),[math]::Max(1,$previewPanel.ClientSize.Height-1))
    $globalAlpha=$(if($script:AnimationActive){$script:AnimationAlpha}else{1.0})
    $bgOpacity=[int]$nudOpacity.Value/100.0

    $c1=Alpha-Color $script:BgColor1 $globalAlpha $bgOpacity
    $c2=Alpha-Color $script:BgColor2 $globalAlpha $bgOpacity

    if($chkGradient.Checked){
        $bgBrush=New-Object System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList @($rect,$c1,$c2,[System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
    } else {
        $bgBrush=New-Object System.Drawing.SolidBrush $c1
    }
    try{$g.FillRectangle($bgBrush,$rect)}finally{$bgBrush.Dispose()}

    if($chkRules.Checked){
        $bc=Alpha-Color $script:BorderColor $globalAlpha 0.5
        $pen=New-Object System.Drawing.Pen -ArgumentList @($bc,[single]2)
        try{
            $g.DrawLine($pen,0,1,$rect.Width,1)
            $g.DrawLine($pen,0,$rect.Height-2,$rect.Width,$rect.Height-2)
        }finally{$pen.Dispose()}
    }

    $font=Get-PreviewFont
    try{
        $textBrush=New-Object System.Drawing.SolidBrush (Alpha-Color $script:TextColor $globalAlpha 1.0)
        try{
            if($script:AnimationActive){
                [void](Load-Logo)
                $text=$PreviewSampleText
                $textSize=$g.MeasureString($text,$font)
                $gap=[int]$nudGap.Value
                $logoH=[int]$nudSize.Value
                $logoW=0
                if($null -ne $script:LogoImage){
                    $logoW=[int][math]::Round($script:LogoImage.Width*($logoH/[double]$script:LogoImage.Height))
                }
                $sideMargin=[int]([math]::Round([int]$nudSize.Value*0.35))
                $totalWidth=$textSize.Width + ($gap*2)
                if($logoW -gt 0){$totalWidth += ($logoW*2)+($sideMargin*4)}
                $script:AnimationSlideWidth=$totalWidth

                $x=[single]$script:AnimationX
                $centerY=$rect.Height/2.0
                if($logoW -gt 0){
                    $logoY=[int]($centerY-$logoH/2)
                    $g.DrawImage($script:LogoImage,[int]$x+$sideMargin,$logoY,$logoW,$logoH)
                    $x += $logoW+($sideMargin*2)+$gap
                }
                $textY=[single]($centerY-($textSize.Height/2))
                $g.DrawString($text,$font,$textBrush,$x,$textY)
                $x += $textSize.Width+$gap
                if($logoW -gt 0){
                    $g.DrawImage($script:LogoImage,[int]$x+$sideMargin,$logoY,$logoW,$logoH)
                }
            }
            elseif($script:PreviewMode -eq "image"){
                if(Load-Logo){
                    Draw-ScaledImageCentered $g $script:LogoImage $rect ([int]$nudSize.Value*2)
                } else {
                    $warn="Logo not found in script folder:`n$($txtLogo.Text)"
                    $fmt=New-Object System.Drawing.StringFormat
                    $fmt.Alignment=[System.Drawing.StringAlignment]::Center
                    $fmt.LineAlignment=[System.Drawing.StringAlignment]::Center
                    try{$g.DrawString($warn,$font,$textBrush,$rect,$fmt)}finally{$fmt.Dispose()}
                }
            }
            else{
                $fmt=New-Object System.Drawing.StringFormat
                $fmt.Alignment=[System.Drawing.StringAlignment]::Center
                $fmt.LineAlignment=[System.Drawing.StringAlignment]::Center
                $fmt.Trimming=[System.Drawing.StringTrimming]::EllipsisCharacter
                try{
                    $inner=New-Object System.Drawing.RectangleF(8,8,$rect.Width-16,$rect.Height-16)
                    $g.DrawString($PreviewSampleText,$font,$textBrush,$inner,$fmt)
                }finally{$fmt.Dispose()}
            }
        }finally{$textBrush.Dispose()}
    }finally{$font.Dispose()}
})

$animTimer=New-Object System.Windows.Forms.Timer
$animTimer.Interval=16
$animTimer.Add_Tick({
    if(-not $script:AnimationActive){$animTimer.Stop();return}

    if($script:AnimationStage -eq "scroll"){
        $elapsed=$script:AnimationWatch.Elapsed.TotalSeconds
        $script:AnimationX=$script:AnimationStartX-([double][int]$nudSpeed.Value*$elapsed)
        if($script:AnimationSlideWidth -gt 0 -and $script:AnimationX -le (-$script:AnimationSlideWidth-4)){
            $script:AnimationStage="fade"
            $script:AnimationWatch.Restart()
        }
    }
    elseif($script:AnimationStage -eq "fade"){
        $fade=[int]$nudFade.Value
        if($fade -le 0){
            $script:AnimationAlpha=0
            $script:AnimationActive=$false
        } else {
            $p=$script:AnimationWatch.Elapsed.TotalMilliseconds/$fade
            $script:AnimationAlpha=[math]::Max(0,1-$p)
            if($p -ge 1){$script:AnimationActive=$false}
        }
    }

    if(-not $script:AnimationActive){
        $animTimer.Stop()
        $script:AnimationStage="idle"
        $script:AnimationAlpha=1.0
        $btnAnimate.Text="Play animation"
    }
    $previewPanel.Invalidate()
})

# -----------------------------
# Events
# -----------------------------

$txtGame.Add_TextChanged({
    if([string]::IsNullOrWhiteSpace($txtKey.Text)){$txtKey.Text=Normalize-Key $txtGame.Text}
})

$btnFilename.Add_Click({
    $k=Normalize-Key $txtKey.Text
    if([string]::IsNullOrWhiteSpace($k)){$k=Normalize-Key $txtGame.Text}
    $txtFile.Text="messages$k.txt"
})

$btnFg.Add_Click({Pick-Color "fg"})
$btnBg1.Add_Click({Pick-Color "bg1"})
$btnBg2.Add_Click({Pick-Color "bg2"})
$btnBorder.Add_Click({Pick-Color "border"})
foreach($tb in @($txtFg,$txtBg1,$txtBg2,$txtBorder)){$tb.Add_Leave({Sync-Colors})}

$btnSwap.Add_Click({
    if($script:PreviewMode -eq "text"){
        $script:PreviewMode="image"
        $lblPreviewMode.Text="Static preview: image"
    } else {
        $script:PreviewMode="text"
        $lblPreviewMode.Text="Static preview: text"
    }
    $previewPanel.Invalidate()
})

$btnAnimate.Add_Click({
    if($script:AnimationActive){
        $script:AnimationActive=$false
        $animTimer.Stop()
        $script:AnimationAlpha=1
        $script:AnimationStage="idle"
        $btnAnimate.Text="Play animation"
        $previewPanel.Invalidate()
        return
    }
    [void](Load-Logo)
    $script:AnimationActive=$true
    $script:AnimationStage="scroll"
    $script:AnimationAlpha=1.0
    $script:AnimationSlideWidth=0
    $script:AnimationStartX=[double]$previewPanel.ClientSize.Width
    $script:AnimationX=$script:AnimationStartX
    $script:AnimationWatch.Restart()
    $btnAnimate.Text="Stop animation"
    $animTimer.Start()
    $previewPanel.Invalidate()
})

foreach($ctrl in @($cmbFont,$nudSize,$nudSpeed,$nudFade,$nudGap,$nudOpacity)){
    if($ctrl -is [System.Windows.Forms.ComboBox]){$ctrl.Add_SelectedIndexChanged({$previewPanel.Invalidate()})}
    else{$ctrl.Add_ValueChanged({$previewPanel.Invalidate()})}
}
$chkGradient.Add_CheckedChanged({$previewPanel.Invalidate()})
$chkRules.Add_CheckedChanged({$previewPanel.Invalidate()})
$txtLogo.Add_TextChanged({Dispose-Logo;$previewPanel.Invalidate()})

$btnCompile.Add_Click({
    $lines=@(Get-AllLines)
    if($chkRequire50.Checked -and $lines.Count -ne 50){
        [void][System.Windows.Forms.MessageBox]::Show(
            "You currently have $($lines.Count) non-empty unique lines. Fill exactly 50, or uncheck 'Require exactly 50'.",
            "Ticker line count",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    if($lines.Count -eq 0){
        [void][System.Windows.Forms.MessageBox]::Show("There are no ticker lines to compile.","Nothing to compile")
        return
    }
    if($chkShuffle.Checked){$lines=@(Shuffle-Array $lines)}
    $dlg=New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter="Text files (*.txt)|*.txt|All files (*.*)|*.*"
    $dlg.FileName=$(if($txtFile.Text.Trim()){$txtFile.Text.Trim()}else{"messages.txt"})
    if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        [System.IO.File]::WriteAllLines($dlg.FileName,$lines,(New-Object System.Text.UTF8Encoding($false)))
        $script:StatusLabel.Text="Wrote $($lines.Count) lines."
    }
})

$btnCopyLines.Add_Click({
    $lines=@(Get-AllLines)
    if($chkShuffle.Checked){$lines=@(Shuffle-Array $lines)}
    if($lines.Count -gt 0){[System.Windows.Forms.Clipboard]::SetText(($lines -join [Environment]::NewLine));$script:StatusLabel.Text="Copied $($lines.Count) lines."}
})

$btnCopyJson.Add_Click({
    $json=Get-PresetObject | ConvertTo-Json -Depth 5
    [System.Windows.Forms.Clipboard]::SetText($json)
    $script:StatusLabel.Text="Copied JSON entry."
})

$btnSaveJson.Add_Click({
    $json=Get-PresetObject | ConvertTo-Json -Depth 5
    $dlg=New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter="JSON files (*.json)|*.json|All files (*.*)|*.*"
    $k=Normalize-Key $txtKey.Text
    if([string]::IsNullOrWhiteSpace($k)){$k="preset"}
    $dlg.FileName="$k-preset.json"
    if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        [System.IO.File]::WriteAllText($dlg.FileName,$json,(New-Object System.Text.UTF8Encoding($false)))
        $script:StatusLabel.Text="Saved JSON entry."
    }
})

$btnSaveProject.Add_Click({
    $json=Get-DraftObject | ConvertTo-Json -Depth 10
    $dlg=New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter="Ticker draft (*.tickerproject.json)|*.tickerproject.json|JSON (*.json)|*.json"
    $k=Normalize-Key $txtKey.Text
    if([string]::IsNullOrWhiteSpace($k)){$k="ticker-draft"}
    $dlg.FileName="$k.tickerproject.json"
    if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        [System.IO.File]::WriteAllText($dlg.FileName,$json,(New-Object System.Text.UTF8Encoding($false)))
        $script:StatusLabel.Text="Saved draft."
    }
})

$btnLoadProject.Add_Click({
    $dlg=New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter="Ticker draft (*.tickerproject.json;*.json)|*.tickerproject.json;*.json|All files (*.*)|*.*"
    if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        try{
            $draft=Get-Content -LiteralPath $dlg.FileName -Raw | ConvertFrom-Json
            Apply-DraftObject $draft
            $script:StatusLabel.Text="Loaded draft."
        }catch{
            [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Could not load draft")
        }
    }
})

$form.Add_Shown({
    Update-LineCount
    Sync-Colors
    $previewPanel.Invalidate()
})

$form.Add_FormClosed({
    Dispose-Logo
    if($null -ne $animTimer){$animTimer.Stop();$animTimer.Dispose()}
})

[void]$form.ShowDialog()

