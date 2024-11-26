import 'dart:math';

import 'package:image/image.dart' as img;

class ImageTools {
  static img.Image invertImage(img.Image src, num shiftCoefficient) {
    final pixels = src.getBytes();

    int pixelId = -1;
    while (pixelId < pixels.length - 1) {
      pixelId += 1;
      var pixel = pixels[pixelId];
      if ((pixelId + 1) % 4 == 0) continue; // alpha channel
      num newPixel = 255 - pixels[pixelId];
      num difference = pixel - newPixel;
      pixels[pixelId] =
          (newPixel + difference * shiftCoefficient).clamp(0, 255).toInt();
    }

    return src;
  }

  static img.Image smudgeImage(
      img.Image src, num smudgeStartPct, bool horizontal) {
    final rgbWidth = src.width * 3;
    final pixels = src.getBytes();

    var rnd = Random();

    int pixelId = -1;
    while (pixelId < pixels.length - 1) {
      pixelId += 1;
      var pixelLinePos = pixelId % rgbWidth;
      var inSmudge = pixelLinePos >
          (rgbWidth * ((smudgeStartPct + rnd.nextInt(10)) / 100));

      if (!inSmudge) continue;
      if (pixelId < 3) continue;
      // var pixel = pixels[pixelId];
      // if ((pixelId + 1) % 4 == 0) continue; // alpha channel

      pixels[pixelId] = pixels[pixelId - 3];
    }

    return src;
  }

  static img.Image mirrorImage(
      img.Image src, num mirrorStartPct, bool horizontal) {
    final rgbWidth = src.width * 3;
    final pixels = src.getBytes();
    final mirrorEdge = (rgbWidth * (mirrorStartPct / 100)).floor();

    int pixelId = -1;
    while (pixelId < pixels.length - 1) {
      pixelId += 1;
      final pastMirror = pixelId > mirrorEdge;

      if (!pastMirror) continue;

      final rgbShift = (mirrorEdge - pixelId).abs() % 3;
      final sourcePixelId = mirrorEdge - (pixelId - mirrorEdge) - rgbShift;

      if (sourcePixelId < 0) continue;

      pixels[pixelId] = pixels[sourcePixelId];
    }

    return src;
  }
}
