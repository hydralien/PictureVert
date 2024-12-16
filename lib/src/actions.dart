enum ActionType { invert, smudge, mirror }

ActionType currentAction(int tabIndex) {
  if (tabIndex == 0) return ActionType.invert;
  if (tabIndex == 1) return ActionType.smudge;
  return ActionType.mirror;
}

// Uint8List createPreview(Image sourceImage, int tabIndex) {
//   final action = currentAction(tabIndex);
//
//   final invertedPreview = ImageTools.invertImage(sourceImage, inversionCoefficient());
//
//   return setState(() {
//     resultImagePreview = Uint8List.fromList(img.encodeJpg(invertedPreview));
//
//   }
