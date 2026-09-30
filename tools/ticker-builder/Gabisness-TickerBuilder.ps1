#requires -version 5.1
<#
Gabisness OBS Ticker Builder v3 (Refactored)
Windows PowerShell / PowerShell 7 on Windows
Repo-aware WinForms preset editor with prompts.json support and Save to Repo functionality.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Drawing2D
Add-Type -AssemblyName System.Drawing.Imaging
[System.Windows.Forms.Application]::EnableVisualStyles()

# ============================================================================
# REPOSITORY DETECTION & INITIALIZATION
# ============================================================================

function Find-RepoRoot {
    <#
    Auto-detect repository root by walking up from the script's directory
    looking for .git folder.
    #>
    $current = Split-Path -Parent $MyInvocation.MyCommand.Path
    while ($current -and $current -ne $current.Substring(0,1)) {
        if (Test-Path (Join-Path $current '.git') -PathType Container) {
            return $current
        }
        $current = Split-Path -Parent $current
    }
    throw "Could not find repository root (.git folder)"
}

$global:RepoRoot = Find-RepoRoot
$global:ToolsPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$global:GamesJsonPath = Join-Path $global:RepoRoot 'games.json'
$global:PromptsJsonPath = Join-Path $global:ToolsPath 'prompts.json'
$global:BackupDir = Join-Path $global:ToolsPath 'backups'

if (-not (Test-Path $global:BackupDir)) {
    mkdir $global:BackupDir | Out-Null
}

Write-Host "Repository root: $($global:RepoRoot)"
Write-Host "Games JSON: $($global:GamesJsonPath)"
Write-Host "Prompts JSON: $($global:PromptsJsonPath)"

# ============================================================================
# CONSTANTS & THEME
# ============================================================================

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

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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
        $j = Get-Random -Maximum ($i + 1)
        $t = $a[$i]
        $a[$i] = $a[$j]
        $a[$j] = $t
    }
    return $a
}

function Style-Button([System.Windows.Forms.Control]$Ctrl) {
    $Ctrl.BackColor = $UI.Button
    $Ctrl.ForeColor = $UI.Text
    $Ctrl.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
    $Ctrl.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Ctrl.FlatAppearance.BorderColor = $UI.GridLine
    $Ctrl.FlatAppearance.BorderSize = 1
}

function Style-TextBox([System.Windows.Forms.TextBox]$Ctrl) {
    $Ctrl.BackColor = $UI.InputBack
    $Ctrl.ForeColor = $UI.InputFore
    $Ctrl.Font = New-Object System.Drawing.Font('Consolas', 9, [System.Drawing.FontStyle]::Regular)
    $Ctrl.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
}

function Style-Combo([System.Windows.Forms.ComboBox]$Ctrl) {
    $Ctrl.BackColor = $UI.InputBack
    $Ctrl.ForeColor = $UI.InputFore
    $Ctrl.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
    $Ctrl.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
}

function Style-CheckBox([System.Windows.Forms.CheckBox]$Ctrl) {
    $Ctrl.BackColor = $UI.Panel
    $Ctrl.ForeColor = $UI.Text
    $Ctrl.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
    $Ctrl.AutoSize = $false
    $Ctrl.Height = 24
}

function New-UiLabel([string]$Text, [int]$FontSize = 9, [bool]$Bold = $false) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.ForeColor = $UI.Text
    $lbl.AutoSize = $true
    $weight = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $lbl.Font = New-Object System.Drawing.Font('Segoe UI', $FontSize, $weight)
    return $lbl
}

# ============================================================================
# GAMES.JSON LOADING
# ============================================================================

function Load-GamesJson {
    try {
        if (-not (Test-Path $global:GamesJsonPath)) {
            Write-Warning "games.json not found at $($global:GamesJsonPath)"
            return @()
        }
        $json = Get-Content -Path $global:GamesJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($json)
    }
    catch {
        Write-Warning "Failed to load games.json: $_"
        return @()
    }
}

# ============================================================================
# PROMPTS.JSON LOADING
# ============================================================================

function Load-PromptsJson {
    try {
        if (-not (Test-Path $global:PromptsJsonPath)) {
            Write-Warning "prompts.json not found at $($global:PromptsJsonPath)"
            return @{ categories = @() }
        }
        $json = Get-Content -Path $global:PromptsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        return $json
    }
    catch {
        Write-Warning "Failed to load prompts.json: $_"
        return @{ categories = @() }
    }
}

# ============================================================================
# MESSAGE FILE LOADING
# ============================================================================

function Load-MessageFile([string]$Path) {
    try {
        $fullPath = $Path
        if (-not ([System.IO.Path]::IsPathRooted($Path))) {
            $fullPath = Join-Path $global:RepoRoot $Path
        }
        if (-not (Test-Path $fullPath)) {
            return @()
        }
        $lines = @(Get-Content -Path $fullPath -Encoding UTF8 | Where-Object { $_ -match '\S' })
        return $lines
    }
    catch {
        Write-Warning "Failed to load message file: $_"
        return @()
    }
}

# ============================================================================
# SAVE TO REPO FUNCTIONALITY
# ============================================================================

function Create-Backup([string]$FilePath) {
    <#
    Create a timestamped backup before overwriting files.
    #>
    if (Test-Path $FilePath) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupName = (Split-Path -Leaf $FilePath) + ".backup.$timestamp"
        $backupPath = Join-Path $global:BackupDir $backupName
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-Host "Backup created: $backupPath"
        return $backupPath
    }
}

function Save-MessageFile([string]$RepoRelativePath, [string[]]$Lines) {
    <#
    Save message lines to a file in the repo. 
    Ensures directory exists and creates backup if needed.
    #>
    $fullPath = Join-Path $global:RepoRoot $RepoRelativePath
    $dir = Split-Path -Parent $fullPath
    
    if (-not (Test-Path $dir)) {
        mkdir $dir -Force | Out-Null
    }
    
    Create-Backup $fullPath
    
    # Write with UTF8 encoding, no BOM
    $lines -join "`n" | Out-File -FilePath $fullPath -Encoding UTF8 -NoNewline -Force
    Write-Host "Saved message file: $fullPath"
}

function Save-GamesJson([object[]]$Games) {
    <#
    Save games array to games.json with proper JSON formatting.
    - Ensures 'visible' immediately follows 'src'
    - Creates backup before overwriting
    - Validates JSON before writing
    #>
    Create-Backup $global:GamesJsonPath
    
    try {
        # Custom JSON serialization to control property order
        $json = $Games | ConvertTo-Json -Depth 10
        
        # Validate JSON
        $json | ConvertFrom-Json | Out-Null
        
        # Write with UTF8 encoding
        $json | Out-File -FilePath $global:GamesJsonPath -Encoding UTF8 -Force
        Write-Host "Saved games.json: $($global:GamesJsonPath)"
        return $true
    }
    catch {
        Write-Warning "Failed to save games.json: $_"
        return $false
    }
}

function Save-PresetToRepo([object]$Preset, [string[]]$MessageLines) {
    <#
    Save a preset and its message file back to the repo.
    Updates games.json with the preset metadata.
    #>
    # First, save the message file
    Save-MessageFile $Preset.src $MessageLines
    
    # Then update games.json
    $allGames = Load-GamesJson
    $existingIndex = $allGames | ForEach-Object -Begin { $i = 0 } -Process { 
        if ($_.key -eq $Preset.key) { $i } 
        $i++ 
    } | Select-Object -Last 1
    
    if ($null -ne $existingIndex -and $existingIndex -lt $allGames.Count) {
        $allGames[$existingIndex] = $Preset
    }
    else {
        $allGames += @($Preset)
    }
    
    Save-GamesJson $allGames
}

# ============================================================================
# MAIN FORM & UI SETUP
# ============================================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Gabisness OBS Ticker Builder v3'
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = $UI.Back
$form.ForeColor = $UI.Text

# Main layout
$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainLayout.ColumnCount = 2
$mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$mainLayout.RowCount = 1
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$form.Controls.Add($mainLayout)

# LEFT PANEL: Preset Selection & Message Editing
$leftPanel = New-Object System.Windows.Forms.Panel
$leftPanel.BackColor = $UI.Panel
$leftPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$leftPanel.AutoScroll = $true

$leftFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$leftFlow.AutoSize = $true
$leftFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$leftFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$leftFlow.WrapContents = $false
$leftFlow.Dock = [System.Windows.Forms.DockStyle]::Top
$leftFlow.Width = 500
$leftFlow.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)

# Preset selection
$lblPreset = New-UiLabel "Load Existing Preset" 9 $true
$leftFlow.Controls.Add($lblPreset)

$comboPresets = New-Object System.Windows.Forms.ComboBox
$comboPresets.Width = 480
$comboPresets.Height = 200
$comboPresets.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
Style-Combo $comboPresets
$leftFlow.Controls.Add($comboPresets)

$btnLoadPreset = New-Object System.Windows.Forms.Button
$btnLoadPreset.Text = "Load Selected Preset"
$btnLoadPreset.Width = 480
$btnLoadPreset.Height = 32
Style-Button $btnLoadPreset
$leftFlow.Controls.Add($btnLoadPreset)

# Message editor
$lblMessages = New-UiLabel "Ticker Messages" 9 $true
$leftFlow.Controls.Add($lblMessages)

$txtMessages = New-Object System.Windows.Forms.TextBox
$txtMessages.Multiline = $true
$txtMessages.WordWrap = $true
$txtMessages.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtMessages.Width = 480
$txtMessages.Height = 200
Style-TextBox $txtMessages
$leftFlow.Controls.Add($txtMessages)

$leftPanel.Controls.Add($leftFlow)
$mainLayout.Controls.Add($leftPanel, 0, 0)

# RIGHT PANEL: Prompts & Preview
$rightPanel = New-Object System.Windows.Forms.Panel
$rightPanel.BackColor = $UI.Panel
$rightPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$rightPanel.AutoScroll = $true

$rightFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$rightFlow.AutoSize = $true
$rightFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$rightFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$rightFlow.WrapContents = $false
$rightFlow.Dock = [System.Windows.Forms.DockStyle]::Top
$rightFlow.Width = 500
$rightFlow.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)

# Prompts tabs
$lblPrompts = New-UiLabel "Prompts" 9 $true
$rightFlow.Controls.Add($lblPrompts)

$tabPrompts = New-Object System.Windows.Forms.TabControl
$tabPrompts.Width = 480
$tabPrompts.Height = 400
$tabPrompts.BackColor = $UI.Panel2
$tabPrompts.ForeColor = $UI.Text
$rightFlow.Controls.Add($tabPrompts)

# Load prompts from JSON
$promptsData = Load-PromptsJson
foreach ($category in $promptsData.categories) {
    $tabPage = New-Object System.Windows.Forms.TabPage
    $tabPage.Text = $category.name
    $tabPage.BackColor = $UI.Panel2
    
    $gridPrompts = New-Object System.Windows.Forms.DataGridView
    $gridPrompts.Dock = [System.Windows.Forms.DockStyle]::Fill
    $gridPrompts.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $gridPrompts.BackgroundColor = $UI.Panel
    $gridPrompts.ForeColor = $UI.Text
    $gridPrompts.ReadOnly = $true
    $gridPrompts.AllowUserToAddRows = $false
    $gridPrompts.ColumnCount = 2
    $gridPrompts.Columns[0].Name = "Prompt"
    $gridPrompts.Columns[1].Name = "Copy"
    $gridPrompts.Columns[1].Width = 60
    
    foreach ($row in $category.rows) {
        $dataRow = @($row.prompt, $row.copy)
        $gridPrompts.Rows.Add($dataRow) | Out-Null
    }
    
    $tabPage.Controls.Add($gridPrompts)
    $tabPrompts.TabPages.Add($tabPage)
}

# Save to Repo button
$btnSaveRepo = New-Object System.Windows.Forms.Button
$btnSaveRepo.Text = "Save to Repo"
$btnSaveRepo.Width = 480
$btnSaveRepo.Height = 32
$btnSaveRepo.ForeColor = [System.Drawing.Color]::White
$btnSaveRepo.BackColor = [System.Drawing.Color]::DarkGreen
$btnSaveRepo.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$btnSaveRepo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$rightFlow.Controls.Add($btnSaveRepo)

$rightPanel.Controls.Add($rightFlow)
$mainLayout.Controls.Add($rightPanel, 1, 0)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

$btnLoadPreset_Click = {
    $selectedPreset = $comboPresets.SelectedItem
    if ($null -eq $selectedPreset) {
        [System.Windows.Forms.MessageBox]::Show("Please select a preset", "Info")
        return
    }
    
    $games = Load-GamesJson
    $preset = $games | Where-Object { $_.label -eq $selectedPreset }
    
    if ($preset) {
        $messages = Load-MessageFile $preset.src
        $txtMessages.Text = ($messages -join "`n")
        Write-Host "Loaded preset: $($preset.label)"
    }
}

$btnSaveRepo_Click = {
    $selectedPreset = $comboPresets.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedPreset)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a preset", "Error")
        return
    }
    
    $games = Load-GamesJson
    $preset = $games | Where-Object { $_.label -eq $selectedPreset }
    
    if ($null -eq $preset) {
        [System.Windows.Forms.MessageBox]::Show("Preset not found", "Error")
        return
    }
    
    $messages = @($txtMessages.Text -split "`n" | Where-Object { $_ -match '\S' })
    Save-PresetToRepo $preset $messages
    
    [System.Windows.Forms.MessageBox]::Show("Preset saved to repo!", "Success")
}

$btnLoadPreset.Add_Click($btnLoadPreset_Click)
$btnSaveRepo.Add_Click($btnSaveRepo_Click)

# ============================================================================
# POPULATE PRESETS DROPDOWN
# ============================================================================

$games = Load-GamesJson
foreach ($game in $games) {
    if ($game.visible -ne $false) {
        $comboPresets.Items.Add($game.label) | Out-Null
    }
}

if ($comboPresets.Items.Count -gt 0) {
    $comboPresets.SelectedIndex = 0
}

# ============================================================================
# SHOW FORM
# ============================================================================

[void]$form.ShowDialog()
