$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class WordmarkCrop {
  public static string Crop(string sourcePath, string destPath) {
    using (var loaded = new Bitmap(sourcePath)) {
      int width = loaded.Width, height = loaded.Height;
      using (var source = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
        using (var g = Graphics.FromImage(source)) g.DrawImage(loaded, 0, 0, width, height);
        var bg = source.GetPixel(2, 2);
        var bits = source.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = bits.Stride;
        byte[] pixels = new byte[stride * height];
        Marshal.Copy(bits.Scan0, pixels, 0, pixels.Length);
        source.UnlockBits(bits);
        int minX = width, minY = height, maxX = 0, maxY = 0;
        for (int y = 0; y < height; y++) {
          int row = y * stride;
          for (int x = 0; x < width; x++) {
            int i = row + x * 4;
            double dr = pixels[i + 2] - bg.R;
            double dg = pixels[i + 1] - bg.G;
            double db = pixels[i] - bg.B;
            if (Math.Sqrt(dr * dr + dg * dg + db * db) > 28) {
              if (x < minX) minX = x;
              if (y < minY) minY = y;
              if (x > maxX) maxX = x;
              if (y > maxY) maxY = y;
            }
          }
        }
        int pad = 56;
        int left = Math.Max(0, minX - pad);
        int top = Math.Max(0, minY - pad);
        int right = Math.Min(width - 1, maxX + pad);
        int bottom = Math.Min(height - 1, maxY + pad);
        var rect = new Rectangle(left, top, right - left + 1, bottom - top + 1);
        using (var crop = source.Clone(rect, PixelFormat.Format32bppArgb)) {
          crop.Save(destPath, ImageFormat.Png);
        }
        return rect.Width + "x" + rect.Height;
      }
    }
  }
}
'@
$here = Split-Path -Parent $PSScriptRoot
if (-not $here) { $here = (Get-Location).Path }
$src = Join-Path $PSScriptRoot 'wordmark.jpg'
$dest = Join-Path $PSScriptRoot 'logo.png'
Write-Output ([WordmarkCrop]::Crop($src, $dest))
