# PictureVert
An image colour inverter app

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