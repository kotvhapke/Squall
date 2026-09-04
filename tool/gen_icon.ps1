Add-Type -AssemblyName System.Drawing

$size = 512
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Rounded dark square background (radius ~22% like macOS icon)
$bgPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = $size * 0.22
$bgPath.AddArc(0, 0, $r * 2, $r * 2, 180, 90)
$bgPath.AddArc($size - $r * 2, 0, $r * 2, $r * 2, 270, 90)
$bgPath.AddArc($size - $r * 2, $size - $r * 2, $r * 2, $r * 2, 0, 90)
$bgPath.AddArc(0, $size - $r * 2, $r * 2, $r * 2, 90, 90)
$bgPath.CloseFigure()
$g.FillPath([System.Drawing.Brushes]::Black, $bgPath)

# Neon glow (blue) around the S - draw S multiple times with increasing blur
$x0 = $size * 0.28
$y0 = $size * 0.22
$w = $size * 0.44
$h = $size * 0.56

# Glow layers - draw thick blue S with various opacities
$glowColors = @(
    @(40, 0, 168, 255),   # outer faint
    @(70, 0, 168, 255),
    @(110, 0, 168, 255),
    @(160, 54, 214, 255)
)
$glowWidths = @(58, 48, 38, 30)

for ($i = 0; $i -lt $glowColors.Length; $i++) {
    $c = $glowColors[$i]
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($c[0], $c[1], $c[2], $c[3]), $glowWidths[$i])
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawLines($pen, $(
        @(New-Object System.Drawing.PointF($x0, $y0 + $h*0.12)),
        @(New-Object System.Drawing.PointF($x0 + $w, $y0)),
        @(New-Object System.Drawing.PointF($x0 + $w, $y0 + $h*0.45)),
        @(New-Object System.Drawing.PointF($x0, $y0 + $h*0.5)),
        @(New-Object System.Drawing.PointF($x0, $y0 + $h*0.88)),
        @(New-Object System.Drawing.PointF($x0 + $w, $y0 + $h))
    ))
    $pen.Dispose()
}

# Solid bright cyan S on top
$solid = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 120, 235, 255), 22)
$solid.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$solid.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$solid.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawLines($solid, $(
    @(New-Object System.Drawing.PointF($x0, $y0 + $h*0.12)),
    @(New-Object System.Drawing.PointF($x0 + $w, $y0)),
    @(New-Object System.Drawing.PointF($x0 + $w, $y0 + $h*0.45)),
    @(New-Object System.Drawing.PointF($x0, $y0 + $h*0.5)),
    @(New-Object System.Drawing.PointF($x0, $y0 + $h*0.88)),
    @(New-Object System.Drawing.PointF($x0 + $w, $y0 + $h))
))
$solid.Dispose()
$g.Dispose()

$outDir = "C:\Users\Administrator\Documents\Squall\squall\assets\branding"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

$bmp.Save("$outDir\squall-icon-user.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Icon PNG saved: $outDir\squall-icon-user.png"