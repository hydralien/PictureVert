# PictureVert

### Picture-what?

<img src="assets/icon_bw.png" alt="App logo" width="100">

It's an image manipulation app, which currently has few abilities:
- Selecting any image from the photo gallery.
- Taking an instant photo and applying effects sto it immediately.
- Inverting image colors with a variable degree of color shift.
- Making a multi-direction color trail from any point of picture with varied jitter and thickness.
- Mirroring halves of the picture in 4 directions.
- Exporting the result by using standard sharing mechanism.

For both import and export, modules from Flutter community are used.

### Flutter

The app is built using Flutter, so here are some references on how to deal with it:
- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)
- [online documentation](https://flutter.dev/docs)

### Icon image refresh
Put icon at `assets/icon.png` and run
```
flutter pub run flutter_launcher_icons:main
``` 
from https://pub.dev/packages/flutter_launcher_icons

### iOS Deployment
Instructions at: https://flutter.dev/docs/deployment/ios#review-xcode-project-settings
- If "Product->Archive" is disabled, select "Product -> Destination -> Any iOS Device"
- If "Any iOS Device" is unavailable, you need to go through AppStore dev registration first and register one device.

### Android deployment
Instructions at https://flutter.dev/docs/deployment/android#build-an-app-bundle
Some notes about the potential troubles: https://hydralien.net/blog/posts/preparing-flutter-app-for-android-release/

### Making Screenshots
iOS Simulator doesn't save screenshots with bezels, so to wrap screenshots into one either a separate app or a bezel image should be used.  
Here's Facebook free library for device frames to aid that: https://design.facebook.com/toolsandresources/devices/

### Example
The app is deployed to e.g. App Store as https://apps.apple.com/app/id1630520634
