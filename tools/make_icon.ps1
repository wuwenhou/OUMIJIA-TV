# Generates assets/icon/app_icon.png (1024x1024) - a flat TV mark for the launcher icon.
Add-Type -AssemblyName System.Drawing

function New-RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

$outDir = Join-Path (Get-Location) "assets\icon"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$bmp = New-Object System.Drawing.Bitmap(1024, 1024)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$bg = [System.Drawing.ColorTranslator]::FromHtml("#0B0F14")
$gold = [System.Drawing.ColorTranslator]::FromHtml("#FFC93C")
$screen = [System.Drawing.ColorTranslator]::FromHtml("#141B23")

$g.Clear($bg)

# antennas
$antennaPen = New-Object System.Drawing.Pen($gold, 30)
$antennaPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$antennaPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($antennaPen, 420, 352, 330, 258)
$g.DrawLine($antennaPen, 604, 352, 694, 258)

# TV body
$bodyPath = New-RoundedPath 232 348 560 368 58
$fillBrush = New-Object System.Drawing.SolidBrush($screen)
$g.FillPath($fillBrush, $bodyPath)
$bodyPen = New-Object System.Drawing.Pen($gold, 34)
$bodyPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPath($bodyPen, $bodyPath)

# play triangle
$play = New-Object System.Drawing.Drawing2D.GraphicsPath
$play.AddPolygon(@(
    [System.Drawing.PointF]::new(462, 470),
    [System.Drawing.PointF]::new(462, 594),
    [System.Drawing.PointF]::new(596, 532)
))
$playBrush = New-Object System.Drawing.SolidBrush($gold)
$g.FillPath($playBrush, $play)

$g.Dispose()
$path = Join-Path $outDir "app_icon.png"
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

$check = [System.Drawing.Image]::FromFile($path)
Write-Host "Icon: $($check.Width)x$($check.Height) - $((Get-Item $path).Length) bytes"
$check.Dispose()
