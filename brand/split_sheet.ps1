# Splits brand/sheet.jpg into the wordmark and the app icon.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class SheetSplit {
  static double Distance(byte r, byte g, byte b, Color bg) {
    double dr = r - bg.R, dg = g - bg.G, db = b - bg.B;
    return Math.Sqrt(dr * dr + dg * dg + db * db);
  }

  public static string Split(string sourcePath, string logoPath, string iconPath) {
    using (var loaded = new Bitmap(sourcePath)) {
      int width = loaded.Width, height = loaded.Height;
      using (var source = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
        using (var g = Graphics.FromImage(source)) g.DrawImage(loaded, 0, 0, width, height);
        var bg = source.GetPixel(8, 8);
        var bits = source.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = bits.Stride;
        byte[] pixels = new byte[stride * height];
        Marshal.Copy(bits.Scan0, pixels, 0, pixels.Length);
        source.UnlockBits(bits);

        int divider = 650;
        int logoMinX = width, logoMinY = height, logoMaxX = 0, logoMaxY = 0;
        int iconMinX = width, iconMinY = height, iconMaxX = 0, iconMaxY = 0;
        for (int y = 0; y < height; y++) {
          int row = y * stride;
          for (int x = 0; x < width; x++) {
            int i = row + x * 4;
            if (Distance(pixels[i + 2], pixels[i + 1], pixels[i], bg) <= 42) continue;
            if (x < divider) {
              if (y < 150 || y > 430) continue;
              if (x < logoMinX) logoMinX = x;
              if (y < logoMinY) logoMinY = y;
              if (x > logoMaxX) logoMaxX = x;
              if (y > logoMaxY) logoMaxY = y;
            } else {
              if (y < 120 || y > 470) continue;
              if (x < iconMinX) iconMinX = x;
              if (y < iconMinY) iconMinY = y;
              if (x > iconMaxX) iconMaxX = x;
              if (y > iconMaxY) iconMaxY = y;
            }
          }
        }

        SaveCrop(source, logoPath, logoMinX, logoMinY, logoMaxX, logoMaxY, 36, false, bg, divider - 8);
        SaveCrop(source, iconPath, iconMinX, iconMinY, iconMaxX, iconMaxY, 24, true, bg, -1);
        return width + "x" + height + " divider=" + divider
          + " logo=" + (logoMaxX - logoMinX) + "x" + (logoMaxY - logoMinY)
          + " icon=" + (iconMaxX - iconMinX) + "x" + (iconMaxY - iconMinY);
      }
    }
  }

  static void SaveCrop(Bitmap source, string path, int minX, int minY, int maxX, int maxY, int pad, bool knockOut, Color bg, int limitRight) {
    int left = Math.Max(0, minX - pad);
    int top = Math.Max(0, minY - pad);
    int right = Math.Min(source.Width - 1, maxX + pad);
    if (limitRight >= 0) right = Math.Min(right, limitRight);
    int bottom = Math.Min(source.Height - 1, maxY + pad);
    var rect = new Rectangle(left, top, right - left + 1, bottom - top + 1);
    using (var crop = source.Clone(rect, PixelFormat.Format32bppArgb)) {
      if (knockOut) {
        for (int y = 0; y < crop.Height; y++) {
          for (int x = 0; x < crop.Width; x++) {
            var color = crop.GetPixel(x, y);
            double dr = color.R - bg.R, dg = color.G - bg.G, db = color.B - bg.B;
            double distance = Math.Sqrt(dr * dr + dg * dg + db * db);
            int alpha = 255;
            if (distance <= 22) alpha = 0;
            else if (distance < 48) alpha = (int)(((distance - 22) / 26.0) * 255);
            crop.SetPixel(x, y, Color.FromArgb(alpha, color.R, color.G, color.B));
          }
        }
      }
      crop.Save(path, ImageFormat.Png);
    }
  }
}
'@

$here = $PSScriptRoot
$sheet = Join-Path $here 'sheet.jpg'
$logo = Join-Path $here 'logo.png'
$icon = Join-Path $here 'icon.png'
Write-Output ([SheetSplit]::Split($sheet, $logo, $icon))

$sizes = 16, 24, 32, 48, 64, 256
$loaded = [System.Drawing.Bitmap]::FromFile($icon)
$pngs = New-Object 'System.Collections.Generic.List[byte[]]'
foreach ($size in $sizes) {
  $bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.DrawImage($loaded, 0, 0, $size, $size)
  $graphics.Dispose()
  $stream = New-Object System.IO.MemoryStream
  $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
  $pngs.Add($stream.ToArray())
}
$loaded.Dispose()

$root = Split-Path -Parent $here
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
Write-Output "Wrote $ico"
