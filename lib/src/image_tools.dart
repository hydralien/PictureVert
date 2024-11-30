import 'dart:math';

import 'package:image/image.dart' as img;

class ImageTools {
  static img.Image invertImage(img.Image src, num shiftCoefficient) {
    final pixels = src.getBytes(order: img.ChannelOrder.rgb);

    int pixelId = -1;
    while (pixelId < pixels.length - 1) {
      pixelId += 1;
      var pixel = pixels[pixelId];
      // if ((pixelId + 1) % 4 == 0) continue; // alpha channel
      num newPixel = 255 - pixels[pixelId];
      num difference = pixel - newPixel;
      pixels[pixelId] =
          (newPixel + difference * shiftCoefficient).clamp(0, 255).toInt();
    }

    return img.Image.fromBytes(
        width: src.width,
        height: src.height,
        order: img.ChannelOrder.rgb,
        bytes: pixels.buffer);
  }

  static img.Image smudgeImage(
      img.Image src, num smudgeStartPct, bool horizontal) {
    final rgbWidth = src.width * 3;
    final pixels = src.getBytes(order: img.ChannelOrder.rgb);

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

    return img.Image.fromBytes(
        width: src.width,
        height: src.height,
        order: img.ChannelOrder.rgb,
        bytes: pixels.buffer);
  }

  static img.Image mirrorImage(
      img.Image src, num mirrorStartPct, bool horizontal) {
    final pixelSize = 3; // RGB
    final rgbWidth = src.width * pixelSize;
    final pixels = src.getBytes(order: img.ChannelOrder.rgb);
    final mirrorEdge = (src.width * (mirrorStartPct / 100)).floor() * pixelSize;

    int pixelId = -1;
    while (pixelId < pixels.length - 1) {
      pixelId += 1;
      final imageId = pixelId + 1;
      if (imageId % pixelSize != 0) continue; // Not a final element in pixel

      var lineIndex = imageId % rgbWidth;
      final pastMirror = lineIndex > mirrorEdge;

      if (!pastMirror) continue;

      final mirrorBackShift = lineIndex - mirrorEdge;
      // final rgbShift = (mirrorBackShift % 3) - 3;
      // final sourcePixelId = pixelId - (mirrorBackShift * 2) + rgbShift;
      if (mirrorBackShift > rgbWidth) continue;
      final sourcePixelId = pixelId - (mirrorBackShift * 2);
      if (sourcePixelId < 2) continue;

      for (var step in Iterable.generate(3)) {
        final int indexStep = step;
        pixels[pixelId - indexStep] = pixels[sourcePixelId - indexStep];
      }

      pixels[pixelId] = pixels[sourcePixelId];
    }

    return img.Image.fromBytes(
        width: src.width,
        height: src.height,
        order: img.ChannelOrder.rgb,
        bytes: pixels.buffer);
  }
}
