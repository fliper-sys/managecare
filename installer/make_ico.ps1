# Converts a PNG (even one mislabeled with an .ico extension) into a real
# multi-resolution Windows .ico file, using the Vista+ ICO format that allows
# each entry to be stored as embedded PNG data instead of raw DIB bits.
# Usage: powershell -File installer\make_ico.ps1 <input-png-or-ico> <output-ico>
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile((Resolve-Path $InputPath))
$sizes = @(256, 128, 64, 48, 32, 16)

$entries = @()
foreach ($size in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, 0, 0, $size, $size)
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $entries += , @{ Size = $size; Bytes = $ms.ToArray() }
    $bmp.Dispose()
}
$src.Dispose()

$fs = New-Object System.IO.FileStream $OutputPath, ([System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter $fs

# ICONDIR
$bw.Write([UInt16]0)          # reserved
$bw.Write([UInt16]1)          # type = icon
$bw.Write([UInt16]$entries.Count)

$headerSize = 6 + (16 * $entries.Count)
$offset = $headerSize
foreach ($e in $entries) {
    $dim = if ($e.Size -ge 256) { 0 } else { $e.Size }  # 0 means 256 in ICO format
    $bw.Write([Byte]$dim)          # width
    $bw.Write([Byte]$dim)          # height
    $bw.Write([Byte]0)             # color count
    $bw.Write([Byte]0)             # reserved
    $bw.Write([UInt16]1)           # planes
    $bw.Write([UInt16]32)          # bit count
    $bw.Write([UInt32]$e.Bytes.Length)
    $bw.Write([UInt32]$offset)
    $offset += $e.Bytes.Length
}
foreach ($e in $entries) {
    $bw.Write($e.Bytes)
}

$bw.Flush()
$bw.Close()
$fs.Close()

Write-Host "Wrote $OutputPath ($($entries.Count) sizes: $($sizes -join ', '))" -ForegroundColor Green
