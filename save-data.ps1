param(
    [string]$Port = 'COM8',
    [ValidateRange(1, 4000000)]
    [int]$BaudRate = 115200,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'recordings'),
    [ValidateRange(0, 86400)]
    [int]$DurationSeconds = 0,
    [switch]$NoWindow
)

# Record until Ctrl+C or the live window closes. Each run creates a new file.
$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new($Port, $BaudRate, 'None', 8, 'One')
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$writer = $null
$stream = $null
$viewer = $null
$textView = $null
$filePath = $null
$count = 0

try {
    try { $serial.Open() } catch {
        throw "Cannot open $Port. Close other serial monitors or recording terminals and check the USB connection. $($_.Exception.Message)"
    }
    [void][System.IO.Directory]::CreateDirectory($OutputDirectory)
    $name = 'flex-data_{0}_{1}.txt' -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss-fff'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $filePath = Join-Path ([System.IO.Path]::GetFullPath($OutputDirectory)) $name
    $stream = [System.IO.File]::Open($filePath, 'CreateNew', 'Write', 'Read')
    $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($true))
    $writer.AutoFlush = $true
    $heading = "ESP32 recording | $Port | $BaudRate baud`r`nStarted: $([DateTimeOffset]::Now.ToString('o'))`r`n"
    $writer.WriteLine($heading)

    if (-not $NoWindow) {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $viewer = [System.Windows.Forms.Form]::new()
        $viewer.Text = "Recording - $name"
        $viewer.Size = [System.Drawing.Size]::new(1000, 650)
        $viewer.StartPosition = 'CenterScreen'
        $textView = [System.Windows.Forms.TextBox]::new()
        $textView.Multiline = $true
        $textView.ReadOnly = $true
        $textView.ScrollBars = 'Both'
        $textView.WordWrap = $false
        $textView.Dock = 'Fill'
        $textView.Font = [System.Drawing.Font]::new('Consolas', 10)
        $textView.Text = $heading + "`r`n"
        $button = [System.Windows.Forms.Button]::new()
        $button.Text = 'Stop, save & close'
        $button.Dock = 'Bottom'
        $button.Height = 45
        $button.Add_Click({ $this.FindForm().Close() })
        $viewer.Controls.Add($textView)
        $viewer.Controls.Add($button)
        $viewer.Show()
    }

    Write-Host "Recording $Port. Press Ctrl+C to stop."
    Write-Host "Saving to: $filePath"
    Write-Host 'Waiting for readings...'
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $pending = ''
    # Skip the first line because connecting can start halfway through a reading.
    $synchronized = $false
    while ($DurationSeconds -eq 0 -or $timer.Elapsed.TotalSeconds -lt $DurationSeconds) {
        if ($viewer) {
            [System.Windows.Forms.Application]::DoEvents()
            if ($viewer.IsDisposed -or -not $viewer.Visible) { break }
        }
        $pending += $serial.ReadExisting()
        $newline = $pending.IndexOf("`n")
        while ($newline -ge 0) {
            $line = $pending.Substring(0, $newline).TrimEnd([char]13)
            $pending = $pending.Substring($newline + 1)
            if (-not $synchronized) {
                $synchronized = $true
            } elseif ($line.Length -gt 0) {
                $entry = '[{0}] {1}' -f [DateTimeOffset]::Now.ToString('o'), $line
                $writer.WriteLine($entry)
                $count++
                Write-Host $entry
                if ($textView) {
                    if ($textView.TextLength -gt 100000) {
                        $textView.Text = "[Earlier readings are saved in the text file.]`r`n" + $textView.Text.Substring($textView.TextLength - 50000)
                    }
                    $textView.AppendText($entry + "`r`n")
                    $textView.SelectionStart = $textView.TextLength
                    $textView.ScrollToCaret()
                }
            }
            $newline = $pending.IndexOf("`n")
        }
        if ($pending.Length -gt 65536) {
            throw 'Received over 64 KB without a newline. Check the baud rate and Serial.println() output.'
        }
        Start-Sleep -Milliseconds 25
    }
} finally {
    try {
        if ($writer) {
            $writer.WriteLine("`r`nStopped: $([DateTimeOffset]::Now.ToString('o')) | Readings saved: $count")
        }
    } finally {
        try {
            if ($writer) { $writer.Dispose() }
        } finally {
            try {
                if ($stream) { $stream.Dispose() }
            } finally {
                try { $serial.Dispose() } finally {
                    if ($viewer) { $viewer.Dispose() }
                }
            }
        }
    }
    if ($filePath) { Write-Host "Recording closed. Saved $count readings to: $filePath" }
}
