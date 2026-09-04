Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Dark background
$g.Clear([System.Drawing.Color]::FromArgb(255, 5, 7, 12))

# Neon glow behind S - draw a blurred blue circle
$glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 0, 168, 255))
$g.FillEllipse($glowBrush, 20, 20, 216, 216)
$glowBrush2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(15, 54, 214, 255))
$g.FillEllipse($glowBrush2, 40, 40, 176, 176)

# Big bold white S
$font = New-Object System.Drawing.Font("Segoe UI", 235, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center
$rectF = New-Object System.Drawing.RectangleF(-12, -12, ($size + 24), ($size + 24))
$g.DrawString("S", $font, $brush, $rectF, $sf)

$g.Dispose()

$outDir = "C:\Users\Administrator\Documents\Squall\squall\assets\branding"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

$bmp.Save("$outDir\squall-icon-user.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Icon PNG saved: $outDir\squall-icon-user.png"