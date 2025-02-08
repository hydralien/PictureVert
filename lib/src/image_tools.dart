import 'dart:math';

import 'package:image/image.dart' as img;

enum Direction { none, right, left, up, down }

const pixelSize = 3; // RGB

class ImageTools {
  static img.Image prepImage(
      {required img.Image src, required Direction direction}) {
    if (direction == Direction.right) return src;
    if (direction == Direction.left) {
      return img.copyFlip(src, direction: img.FlipDirection.horizontal);
    }
    if (direction == Direction.up) {
      return img.copyRotate(
        src,
        angle: 90,
        // interpolation: img.Interpolation.cubic
      );
    }
    if (direction == Direction.down) {
      return img.copyRotate(
        src,
        angle: -90,
        // interpolation: img.Interpolation.cubic
      );
    }
    return src;
  }

  static img.Image unprepImage(
      {required img.Image src, required Direction direction}) {
    if (direction == Direction.right) return src;
    if (direction == Direction.left) {
      return img.copyFlip(src, direction: img.FlipDirection.horizontal);
    }
    if (direction == Direction.up) {
      return img.copyRotate(
        src,
        angle: -90,
        // interpolation: img.Interpolation.cubic
      );
    }
    if (direction == Direction.down) {
      return img.copyRotate(
        src,
        angle: 90,
        // interpolation: img.Interpolation.cubic
      );
    }
    return src;
  }

  static img.Image invertImage(
      {required img.Image src, required num shiftCoefficient}) {
    final pixels = src.getBytes(order: img.ChannelOrder.rgb);

    int pixelId = -1;
    while (pixelId < pixels.length - 1) {
      pixelId += 1;
      var pixel = pixels[pixelId];
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
      {required img.Image src,
      num smudgeStartPct = 50,
      Direction direction = Direction.right,
      num lineSize = 1,
      num jitter = 0}) {
    final adjustedSmudgeStart =
        direction == Direction.left ? 100 - smudgeStartPct : smudgeStartPct;
    final preppedImage = prepImage(src: src, direction: direction);
    final rgbWidth = preppedImage.width * pixelSize;
    final pixels = preppedImage.getBytes(order: img.ChannelOrder.rgb);
    final lineThicknessPct = lineSize / 100;
    final lineThickness =
        (preppedImage.height * lineThicknessPct / 100).floor();
    final maxLineThickness = max(lineThickness, 1);
    // Leaving for maybe some day?
    final colorAverage = true;
    // final colorAverage = false;

    final rnd = Random();
    num getJitter(num lineNo) {
      // Wavy line - maybe some day
      // final smoothValue = log(lineNo * 100) / log(10);
      // final smoothValue = lineNo * 50;
      // final jitterBase = sin(smoothValue);
      // final jitterResult = jitterBase * jitter;
      // return jitterResult.floor();
      final jitterBase = rnd.nextDouble() * jitter;
      return jitterBase;
    }

    final List<(int r, int g, int b, int smudgePos)> lineColors = [];

    // var lineNo = 1;
    var lineJitter = getJitter(0);
    for (var lineNo in Iterable.generate(preppedImage.height)) {
      var smudgePos =
          ((preppedImage.width) * ((adjustedSmudgeStart + lineJitter) / 100))
                  .floor() *
              pixelSize;
      if (smudgePos >= preppedImage.width * pixelSize) {
        smudgePos = (preppedImage.width * pixelSize) - pixelSize;
      }

      final pixelSmudgePos = (rgbWidth * lineNo + smudgePos).toInt();
      if (lineNo % maxLineThickness == 0) {
        lineJitter = getJitter(lineNo / preppedImage.height);
        if (colorAverage) {
          lineColors.add((0, 0, 0, smudgePos));
        } else {
          lineColors.add((
            pixels[pixelSmudgePos],
            pixels[pixelSmudgePos + 1],
            pixels[pixelSmudgePos + 2],
            smudgePos
          ));
        }
      }
      if (!colorAverage) continue;

      final lineColor = lineColors[lineColors.length - 1];

      lineColors[lineColors.length - 1] = (
        lineColor.$1 + (pixels[pixelSmudgePos] / maxLineThickness).round(),
        lineColor.$2 + (pixels[pixelSmudgePos + 1] / maxLineThickness).round(),
        lineColor.$3 + (pixels[pixelSmudgePos + 2] / maxLineThickness).round(),
        lineColor.$4
      );
      // lineNo += 1;
    }

    for (var lineNo in Iterable.generate(preppedImage.height)) {
      final lineColorIndex = (lineNo / maxLineThickness).floor();
      final lineColor = lineColors[lineColorIndex];
      final smudgePos = lineColor.$4;

      for (var pixelLinePos in Iterable.generate(rgbWidth)) {
        final pixelId = lineNo * rgbWidth + pixelLinePos;

        var inSmudge = pixelLinePos >= smudgePos;

        if (!inSmudge) continue;
        if (pixelId < pixelSize) continue;

        final lineColorRgb = [lineColor.$1, lineColor.$2, lineColor.$3];
        pixels[pixelId] = lineColorRgb[pixelId % pixelSize];
      }
    }

    return unprepImage(
        src: img.Image.fromBytes(
            width: preppedImage.width,
            height: preppedImage.height,
            order: img.ChannelOrder.rgb,
            bytes: pixels.buffer),
        direction: direction);
  }

  static img.Image mirrorImage({
    required img.Image src,
    num mirrorStartPct = 50,
    Direction direction = Direction.right,
    Direction secondaryDirection = Direction.none,
  }) {
    final preppedImage = prepImage(src: src, direction: direction);
    final rgbWidth = preppedImage.width * pixelSize;
    final pixels = preppedImage.getBytes(order: img.ChannelOrder.rgb);
    final mirrorEdge =
        (preppedImage.width * (mirrorStartPct / 100)).floor() * pixelSize;

    int pixelId = -1;
    while (pixelId < pixels.length - 1) {
      pixelId += 1;
      final imageId = pixelId + 1;
      if (imageId % pixelSize != 0) continue; // Not a final element in pixel

      var lineIndex = imageId % rgbWidth;
      final pastMirror = lineIndex > mirrorEdge;

      if (!pastMirror) continue;

      final mirrorBackShift = lineIndex - mirrorEdge;
      // final rgbShift = (mirrorBackShift % pixelSize) - pixelSize;
      // final sourcePixelId = pixelId - (mirrorBackShift * 2) + rgbShift;
      if (mirrorBackShift > rgbWidth) continue;
      final sourcePixelId = pixelId - (mirrorBackShift * 2);
      if (sourcePixelId < 2) continue;

      for (var step in Iterable.generate(pixelSize)) {
        final int indexStep = step;
        pixels[pixelId - indexStep] = pixels[sourcePixelId - indexStep];
      }

      pixels[pixelId] = pixels[sourcePixelId];
    }

    var firstStageImage = unprepImage(
        src: img.Image.fromBytes(
            width: preppedImage.width,
            height: preppedImage.height,
            order: img.ChannelOrder.rgb,
            bytes: pixels.buffer),
        direction: direction);

    if (secondaryDirection == Direction.none) {
      return firstStageImage;
    }

    return mirrorImage(
        src: firstStageImage,
        mirrorStartPct: mirrorStartPct,
        direction: secondaryDirection,
        secondaryDirection: Direction.none);
  }
}
