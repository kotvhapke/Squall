Add-Type -AssemblyName System.Drawing
$src = "C:\Users\Administrator\Documents\Squall\squall\assets\branding\squall-icon-user.png"
$tmp = "C:\Users\Administrator\Documents\Squall\squall\assets\branding\squall-icon-user-transparent.png"
$bmp = [System.Drawing.Bitmap]::new($src)
$out = [System.Drawing.Bitmap]::new($bmp.Width, $bmp.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($out)
$g.Clear([System.Drawing.Color]::Transparent)

for ($y=0; $y -lt $bmp.Height; $y++) {
  for ($x=0; $x -lt $bmp.Width; $x++) {
    $p = $bmp.GetPixel($x,$y)
    $lum = [int](0.299*$p.R + 0.587*$p.G + 0.114*$p.B)
    if ($lum -lt 25) { continue }
    $a = [Math]::Min(255, [int]($lum * 2.0))
    if ($a -lt 70) { continue }
    $out.SetPixel($x,$y,[System.Drawing.Color]::FromArgb([Math]::Min(255,$a), [Math]::Min(255,$p.R), [Math]::Min(255,$p.G), [Math]::Min(255,$p.B)))
  }
}
$g.Dispose()
$bmp.Dispose()
$out.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose()
Copy-Item $tmp $src -Force
Remove-Item $tmp -Force

$v=[System.Drawing.Bitmap]::new($src)
$c=$v.GetPixel(0,0); Write-Output "corner A=$($c.A)"
$c2=$v.GetPixel([int]($v.Width/2),[int]($v.Height/2)); Write-Output "center A=$($c2.A) R=$($c2.R)"
$v.Dispose()
Write-Output "DONE"