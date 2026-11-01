# Builds the icon and the wordmark from brand/logo.jpeg.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not ('InsightBrand' -as [type])) {
  Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class InsightBrand {
  static double Distance(byte r, byte g, byte b, Color bg) {
    double dr = r - bg.R;
    double dg = g - bg.G;
    double db = b - bg.B;
    return Math.Sqrt(dr * dr + dg * dg + db * db);
  }

  public static Bitmap CutIcon(string path) {
    using (var loaded = new Bitmap(path)) {
      int width = loaded.Width;
      int height = loaded.Height;
      var source = new Bitmap(width, height, PixelFormat.Format32bppArgb);
      using (var graphics = Graphics.FromImage(source)) {
        graphics.DrawImage(loaded, 0, 0, width, height);
      }
      var background = source.GetPixel(2, 2);
      var bits = source.LockBits(
        new Rectangle(0, 0, width, height),
        ImageLockMode.ReadWrite,
        PixelFormat.Format32bppArgb
      );
      int stride = bits.Stride;
      int count = stride * height;
      byte[] pixels = new byte[count];
      Marshal.Copy(bits.Scan0, pixels, 0, count);

      int minX = width, minY = height, maxX = 0, maxY = 0;
      for (int y = 0; y < height; y++) {
        int row = y * stride;
        for (int x = 0; x < width; x++) {
          int i = row + x * 4;
          double distance = Distance(pixels[i + 2], pixels[i + 1], pixels[i], background);
          if (distance > 36) {
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x > maxX) maxX = x;
            if (y > maxY) maxY = y;
          }
        }
      }

      int side = Math.Max(maxX - minX + 1, maxY - minY + 1) + 8;
      int centerX = (minX + maxX) / 2;
      int centerY = (minY + maxY) / 2;
      int left = Math.Max(0, centerX - side / 2);
      int top = Math.Max(0, centerY - side / 2);
      if (left + side > width) side = width - left;
      if (top + side > height) side = height - top;

      var master = new Bitmap(side, side, PixelFormat.Format32bppArgb);
      for (int y = 0; y < side; y++) {
        int row = (top + y) * stride;
        for (int x = 0; x < side; x++) {
          int i = row + (left + x) * 4;
          byte b = pixels[i];
          byte g = pixels[i + 1];
          byte r = pixels[i + 2];
          double distance = Distance(r, g, b, background);
          int alpha = 255;
          if (distance <= 28) alpha = 0;
          else if (distance < 70) alpha = (int)(((distance - 28) / 42.0) * 255);
          master.SetPixel(x, y, Color.FromArgb(alpha, r, g, b));
        }
      }
      source.UnlockBits(bits);
      source.Dispose();
      return master;
    }
  }
}
'@
}

$master = [InsightBrand]::CutIcon((Join-Path $PSScriptRoot 'logo.jpeg'))

function Save-Sized([System.Drawing.Bitmap]$from, [int]$size, [string]$path) {
  $bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.DrawImage($from, 0, 0, $size, $size)
  $graphics.Dispose()
  $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}

$iconPng = Join-Path $PSScriptRoot 'icon.png'
Save-Sized $master 512 $iconPng

$logo = New-Object System.Drawing.Bitmap 520, 160, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$draw = [System.Drawing.Graphics]::FromImage($logo)
$draw.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$draw.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$draw.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$draw.Clear([System.Drawing.Color]::Transparent)
$draw.DrawImage($master, 8, 8, 144, 144)
$font = [System.Drawing.Font]::new(
  'Georgia',
  52,
  [System.Drawing.FontStyle]::Regular,
  [System.Drawing.GraphicsUnit]::Pixel
)
$ink = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#12304F'))
$draw.DrawString('Insight', $font, $ink, 176, 48)
$ink.Dispose()
$font.Dispose()
$draw.Dispose()
$logoPath = Join-Path $PSScriptRoot 'logo.png'
$logo.Save($logoPath, [System.Drawing.Imaging.ImageFormat]::Png)
$logo.Dispose()
$master.Dispose()

$sizes = 16, 24, 32, 48, 64, 256
$icon = [System.Drawing.Bitmap]::FromFile($iconPng)
$pngs = New-Object 'System.Collections.Generic.List[byte[]]'
foreach ($size in $sizes) {
  $bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.DrawImage($icon, 0, 0, $size, $size)
  $graphics.Dispose()
  $stream = New-Object System.IO.MemoryStream
  $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
  $pngs.Add($stream.ToArray())
}
$icon.Dispose()

$root = Split-Path -Parent $PSScriptRoot
$ico = Join-Path $root 'tool\analyzer\windows\runner\resources\app_icon.ico'
$count = $pngs.Count
$offset = 6 + (16 * $count)
$out = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter $out
$writer.Write([uint16]0)
$writer.Write([uint16]1)
$writer.Write([uint16]$count)
for ($i = 0; $i -lt $count; $i++) {
  $dimension = $sizes[$i]
  $byte = if ($dimension -ge 256) { [byte]0 } else { [byte]$dimension }
  $writer.Write($byte)
  $writer.Write($byte)
  $writer.Write([byte]0)
  $writer.Write([byte]0)
  $writer.Write([uint16]1)
  $writer.Write([uint16]32)
  $writer.Write([uint32]$pngs[$i].Length)
  $writer.Write([uint32]$offset)
  $offset += $pngs[$i].Length
}
foreach ($png in $pngs) { $writer.Write($png) }
$writer.Flush()
[System.IO.File]::WriteAllBytes($ico, $out.ToArray())
$writer.Dispose()

Write-Output "Wrote $iconPng"
Write-Output "Wrote $logoPath"
Write-Output "Wrote $ico"
