# PictureVert

### Picture-what?

![Another screenshot](assets/icon_indigo.png =150x150)

It's an image colour inverter app, which currently does one thing only: inverts color on a chosen image.

So it imports an image from a library or camera, inverts colors according to an inversion shift (there's a slider) and exports the image to where required. For both import and export, modules from Flutter community are used.

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
