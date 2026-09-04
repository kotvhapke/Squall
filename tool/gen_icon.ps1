Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Dark background
$g.Clear([System.Drawing.Color]::FromArgb(255, 5, 7, 12))

# Big bold white S, centered, occupying ~90% of the canvas
$font = New-Object System.Drawing.Font("Segoe UI", 235, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center

# Use RectangleF (proper type for DrawString overload)
$rectF = New-Object System.Drawing.RectangleF(-12, -12, ($size + 24), ($size + 24))
$g.DrawString("S", $font, $brush, $rectF, $sf)

$g.Dispose()

# Ensure output dir
$outDir = "C:\Users\Administrator\Documents\Squall\squall\assets\branding"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

$bmp.Save("$outDir\squall-icon-user.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Icon PNG saved: $outDir\squall-icon-user.png"