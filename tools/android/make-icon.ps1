# Draws the launcher icon (assets/icon.png): the app's tomato-red to warm
# orange tile with a timer dial cut into it, 512x512.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\assets\icon.png'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$size = 512
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# Rounded tile with the brand gradient.
$r = 112
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$d = 2 * $r
$path.AddArc(0, 0, $d, $d, 180, 90)
$path.AddArc($size - $d, 0, $d, $d, 270, 90)
$path.AddArc($size - $d, $size - $d, $d, $d, 0, 90)
$path.AddArc(0, $size - $d, $d, $d, 90, 90)
$path.CloseFigure()
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point 0, 0),
    (New-Object System.Drawing.Point $size, $size),
    [System.Drawing.ColorTranslator]::FromHtml('#e8455b'),
    [System.Drawing.ColorTranslator]::FromHtml('#ff8a5b'))
$g.FillPath($brush, $path)

# Dial: a white ring, a knob on top and a hand.
$white = [System.Drawing.Color]::FromArgb(250, 255, 255, 255)
$ringPen = New-Object System.Drawing.Pen $white, 30
$ringPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$ringPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawEllipse($ringPen, 124, 148, 264, 264)

$knob = New-Object System.Drawing.Drawing2D.GraphicsPath
$knob.AddArc(220, 96, 72, 44, 180, 180)
$knob.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush $white), $knob)

$handPen = New-Object System.Drawing.Pen $white, 26
$handPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$handPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($handPen, 256, 280, 202, 226)
$g.FillEllipse((New-Object System.Drawing.SolidBrush $white), 238, 262, 36, 36)

$dir = Split-Path -Parent $Out
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $brush.Dispose(); $ringPen.Dispose(); $handPen.Dispose(); $path.Dispose(); $knob.Dispose()
Write-Output $Out
