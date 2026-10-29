# Erzeugt das App-Symbol (Filz + zwei Karten) in allen Android-Launcher-Größen.
# Aufruf: powershell -File make_icons.ps1   (schreibt ic_launcher_<n>.png neben dieses Skript)
Add-Type -AssemblyName System.Drawing
$dir = $PSScriptRoot

function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object Drawing.Drawing2D.GraphicsPath
  $p.AddArc($x, $y, 2 * $r, 2 * $r, 180, 90)
  $p.AddArc($x + $w - 2 * $r, $y, 2 * $r, 2 * $r, 270, 90)
  $p.AddArc($x + $w - 2 * $r, $y + $h - 2 * $r, 2 * $r, 2 * $r, 0, 90)
  $p.AddArc($x, $y + $h - 2 * $r, 2 * $r, 2 * $r, 90, 90)
  $p.CloseFigure()
  return $p
}

function Card($g, [float]$cx, [float]$cy, [float]$angle, [string]$rank, [string]$suit, $color) {
  $w = 210; $h = 300
  $st = $g.Save()
  $g.TranslateTransform($cx, $cy); $g.RotateTransform($angle)
  $shadow = RoundRect (-$w / 2 + 8) (-$h / 2 + 12) $w $h 22
  $g.FillPath((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(90, 0, 0, 0))), $shadow)
  $body = RoundRect (-$w / 2) (-$h / 2) $w $h 22
  $g.FillPath((New-Object Drawing.Drawing2D.LinearGradientBrush ((New-Object Drawing.PointF 0, (-$h / 2)), (New-Object Drawing.PointF 0, ($h / 2)), [Drawing.Color]::White, [Drawing.Color]::FromArgb(240, 234, 220))), $body)
  $g.DrawPath((New-Object Drawing.Pen ([Drawing.Color]::FromArgb(201, 162, 39)), 6), $body)
  $b = New-Object Drawing.SolidBrush $color
  $g.DrawString($rank, (New-Object Drawing.Font 'Georgia', 46, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)), $b, (-$w / 2 + 14), (-$h / 2 + 8))
  $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $g.DrawString($suit, (New-Object Drawing.Font 'Segoe UI Symbol', 150, ([Drawing.GraphicsUnit]::Pixel)), $b, (New-Object Drawing.RectangleF (-$w / 2), (-$h / 2 + 30), $w, $h), $sf)
  $g.Restore($st)
}

$S = 512
$bmp = New-Object Drawing.Bitmap $S, $S
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.InterpolationMode = 'HighQualityBicubic'
$g.Clear([Drawing.Color]::Transparent)
$bg = RoundRect 16 16 480 480 96
$pb = New-Object Drawing.Drawing2D.PathGradientBrush $bg
$pb.CenterColor = [Drawing.Color]::FromArgb(36, 138, 84)
$pb.SurroundColors = @([Drawing.Color]::FromArgb(10, 46, 28))
$g.FillPath($pb, $bg)
$g.DrawPath((New-Object Drawing.Pen ([Drawing.Color]::FromArgb(201, 162, 39)), 8), $bg)
Card $g 214 266 -14 'K' ([string][char]0x2663) ([Drawing.Color]::FromArgb(27, 27, 31))
Card $g 300 262 12 'A' ([string][char]0x2665) ([Drawing.Color]::FromArgb(211, 47, 47))
$g.Dispose()
$bmp.Save("$dir\ic_launcher_512.png")

foreach ($n in 36, 48, 72, 96, 144, 192) {
  $s = New-Object Drawing.Bitmap $n, $n
  $sg = [Drawing.Graphics]::FromImage($s)
  $sg.InterpolationMode = 'HighQualityBicubic'; $sg.SmoothingMode = 'AntiAlias'; $sg.PixelOffsetMode = 'HighQuality'
  $sg.DrawImage($bmp, 0, 0, $n, $n)
  $sg.Dispose()
  $s.Save("$dir\ic_launcher_$n.png")
}
