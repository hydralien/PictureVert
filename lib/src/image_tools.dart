import 'dart:math';

import 'package:image/image.dart' as img;

enum Direction { right, left, up, down }

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

    final rnd = Random();
    int getJitter(num lineNo) {
      // Wavy line - maybe some day
      // final smoothValue = log(lineNo * 100) / log(10);
      // final smoothValue = lineNo * 50;
      // final jitterBase = sin(smoothValue);
      // final jitterResult = jitterBase * jitter;
      // return jitterResult.floor();
      final smoothValue = ((jitter / 10) * preppedImage.width) / 100;
      final jitterBase = rnd.nextDouble() * smoothValue;
      return (jitterBase).toInt();
    }

    final List<(int r, int g, int b, int j)> lineColors = [];

    var lineNo = 1;
    var lineJitter = getJitter(0);
    while (lineNo <= preppedImage.height) {
      var smudgePos =
          (preppedImage.width * ((adjustedSmudgeStart + lineJitter) / 100))
                  .floor() *
              pixelSize;
      if (smudgePos >= preppedImage.width * pixelSize) {
        smudgePos = (preppedImage.width * pixelSize) - pixelSize;
      }
      if (lineNo == 1 || lineNo % maxLineThickness == 0) {
        lineJitter = getJitter(lineNo / preppedImage.height);
        lineColors.add((0, 0, 0, lineJitter));
      }
      final lineColor = lineColors[lineColors.length - 1];
      final pixelSmudgePos = smudgePos * lineNo;
      lineColors[lineColors.length - 1] = (
        lineColor.$1 + (pixels[pixelSmudgePos] / maxLineThickness).floor(),
        lineColor.$2 + (pixels[pixelSmudgePos + 1] / maxLineThickness).floor(),
        lineColor.$3 + (pixels[pixelSmudgePos + 2] / maxLineThickness).floor(),
        lineColor.$4
      );
      lineNo += 1;
    }

    for (var lineNo in Iterable.generate(preppedImage.height)) {
      final lineColorIndex = (lineNo / maxLineThickness).floor();
      final lineColor = lineColors[lineColorIndex];
      final lineJitter = lineColor.$4;

      final smudgePos =
          (preppedImage.width * ((adjustedSmudgeStart + lineJitter) / 100))
                  .floor() *
              pixelSize;
      print({
        "smudgePos": smudgePos,
        "lineJitter": lineJitter,
        "lineNo": lineNo,
        "rgbWidth": rgbWidth,
        "preppedImage.width": preppedImage.width
      });
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

  static img.Image mirrorImage(
      {required img.Image src,
      num mirrorStartPct = 50,
      Direction direction = Direction.right}) {
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

    return unprepImage(
        src: img.Image.fromBytes(
            width: preppedImage.width,
            height: preppedImage.height,
            order: img.ChannelOrder.rgb,
            bytes: pixels.buffer),
        direction: direction);
  }
}
